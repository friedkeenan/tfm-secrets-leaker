package {
    import flash.display.Sprite;
    import flash.system.LoaderContext;
    import flash.system.ApplicationDomain;
    import flash.events.Event;
    import flash.net.URLLoader;
    import flash.net.URLRequest;
    import flash.display.Loader;
    import flash.display.DisplayObjectContainer;
    import flash.utils.describeType;
    import flash.system.fscommand;
    import flash.utils.ByteArray;

    public class TFMSecretsLeaker extends Sprite {
        private var final_loader: Loader;
        private var connection_class_info: *;

        private var server_address: String;

        public function TFMSecretsLeaker() {
            super();

            /*
                We load the game just as the vanilla loader does,
                and then we inspect and fiddle with the loaded game
                to obtain its hardcoded secrets.
            */

            var loader: * = new URLLoader();
            loader.dataFormat = "binary";

            var ctx: * = new LoaderContext();
            ctx.allowCodeImport = true;
            ctx.applicationDomain = ApplicationDomain.currentDomain;

            loader.addEventListener(Event.COMPLETE, this.game_data_loaded);

            loader.load(new URLRequest("http://www.transformice.com/Transformice.swf?d=" + new Date().getTime()));
        }

        private function game_data_loaded(event: Event) : void {
            this.final_loader = new Loader();
            this.final_loader.contentLoaderInfo.addEventListener(Event.COMPLETE, this.game_code_loaded);

            var ctx: * = new LoaderContext();
            ctx.allowCodeImport = true;

            this.addChild(this.final_loader);
            this.final_loader.loadBytes(URLLoader(event.currentTarget).data, ctx);
        }

        private function game_code_loaded(event: Event) : void {
            this.addEventListener(Event.ENTER_FRAME, this.get_connection_class_info);
        }

        private static function get_socket_property(description: XML) : String {
            for each (var variable: * in description.elements("factory").elements("variable")) {
                if (variable.attribute("type") == "flash.net::Socket") {
                    return variable.attribute("name");
                }
            }

            return null;
        }

        private static function get_connection_instance_name(description: XML) : String {
            var connection_name: String = description.attribute("name");

            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") == connection_name) {
                    /*
                        NOTE: Both instances at the point we care about
                        are the same object, so we just return the first
                        that we find.
                    */
                    return variable.attribute("name");
                }
            }

            return null;
        }

        private static function get_address_prop_name(description: XML) : String {
            for each (var variable: * in description.elements("factory").elements("variable")) {
                /*
                    NOTE: There are two non-static properties which
                    are strings, but they both hold the same value.
                */
                if (variable.attribute("type") == "String") {
                    return variable.attribute("name");
                }
            }

            return null;
        }

        private function get_connection_class_info(event: Event) : void {
            var game: * = (this.final_loader.content as DisplayObjectContainer).getChildAt(0) as Loader;

            if (game.numChildren == 0) {
                return;
            }

            this.removeEventListener(Event.ENTER_FRAME, this.get_connection_class_info);

            var domain: * = game.contentLoaderInfo.applicationDomain;
            for each(var class_name: String in domain.getQualifiedDefinitionNames()) {
                /*
                    The connection class is the only one that only
                    inherits from 'Object', doesn't implement any
                    interface, and has a non-static 'Socket' property.
                */

                var klass: * = domain.getDefinition(class_name);
                if (klass.constructor != Class) {
                    continue;
                }

                var description: * = describeType(klass);

                if (description.elements("factory").elements("extendsClass").length() != 1) {
                    continue;
                }

                if (description.elements("factory").elements("implementsInterface").length() != 0) {
                    continue;
                }

                var socket_prop_name: String = get_socket_property(description);
                if (socket_prop_name == null) {
                    continue;
                }

                var address_prop_name: * = get_address_prop_name(description);
                var instance_name:     * = get_connection_instance_name(description);

                this.connection_class_info = {
                    klass: klass,
                    socket_prop_name: socket_prop_name,
                    address_prop_name: address_prop_name,
                    instance_name: instance_name
                };

                this.addEventListener(Event.ENTER_FRAME, this.try_replace_socket);

                return;
            }
        }

        private function try_replace_socket(event: Event) : void {
            var klass: Class = this.connection_class_info.klass;
            var instance: * = klass[this.connection_class_info.instance_name]

            if (instance == null) {
                return;
            }

            var socket_prop_name: * = this.connection_class_info.socket_prop_name;

            var socket: * = instance[socket_prop_name]
            if (!socket.hasEventListener(Event.CONNECT)) {
                return;
            }

            /* Close the socket to better avoid any connection to the server. */
            socket.close();

            this.removeEventListener(Event.ENTER_FRAME, this.try_replace_socket);

            this.server_address = instance[this.connection_class_info.address_prop_name];

            /*
                Replace the connection's socket with our own socket
                which will keep track of the handshake packet for us.
            */
            instance[socket_prop_name] = new HandshakeLeakerSocket(this.on_handshake);

            /* Dispatch fake connection event to trigger handshake packet. */
            socket.dispatchEvent(new Event(Event.CONNECT));
        }

        private function get_handshake_secrets(data: ByteArray) : * {
            /*
                Here we get the body of the handshake packet that was
                attempted to be sent, and read out the secret-containing
                fields.
            */

            /* Packet ID. */
            data.readUnsignedByte();
            data.readUnsignedByte();

            var game_version: * = data.readShort();

            /* Language. */
            data.readUTF();

            var connection_token: * = data.readUTF();

            return {
                game_version:     game_version,
                connection_token: connection_token
            };
        }

        private function get_auth_key(document: *) : int {
            var description: * = describeType(document);
            for each (var method: * in description.elements("method")) {
                /*
                    The method that ciphers the auth token is the only
                    one in the document class that is non-static, takes
                    no parameters, and returns 'int'.
                */

                if (method.attribute("returnType") != "int") {
                    continue;
                }

                if (method.elements("parameter").length() != 0) {
                    continue;
                }

                var cipher_method: * = document[method.attribute("name")];
                if (cipher_method == null) {
                    continue;
                }

                /*
                    NOTE: At this point, the auth token is still '0',
                    and since ciphering the auth token is equivalent
                    to a single XOR, and since '0 ^ key == key', we
                    can get the auth key simply by calling the method.
                */
                var auth_key: int = cipher_method.call(document);

                return auth_key;
            }

            return null;
        }

        private function get_packet_key_sources(document: *) : Array {
            var description: * = describeType(document);
            for each (var variable: * in description.elements("variable")) {
                /*
                    The key sources array is defined as an
                    'Object' but in fact holds an 'Array'.
                */

                if (variable.attribute("type") != "Object") {
                    continue;
                }

                var name: String = variable.attribute("name");

                var prop: * = document[name];
                if (prop == null) {
                    continue;
                }

                if (prop.constructor != Array) {
                    continue;
                }

                return prop;
            }

            return null;
        }

        private function on_handshake(data: ByteArray) : void {
            var handshake_secrets: * = this.get_handshake_secrets(data);

            var game:     * = (this.final_loader.content as DisplayObjectContainer).getChildAt(0) as Loader;
            var document: * = game.getChildAt(0);

            var auth_key:           * = this.get_auth_key(document);
            var packet_key_sources: * = this.get_packet_key_sources(document);

            trace("Server Address:    ", this.server_address);
            trace("Game Version:      ", handshake_secrets.game_version);
            trace("Connection Token:  ", handshake_secrets.connection_token);
            trace("Auth Key:          ", auth_key);
            trace("Packet Key Sources:", packet_key_sources);

            fscommand("quit");
        }
    }
}