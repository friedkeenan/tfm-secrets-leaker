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
        /*
            NOTE: We use this value to make it easy to replace
            in the client verification data and hard for the
            other random data to collide with. In particular
            each byte being different makes it impossible for
            a single byte to mess with this replacement, for
            instance if we used '0xAAAAAAAA' then if just another
            '0xAA' showed up next to the verification token, it
            would mess the template up.

            This token also uses bytes which would just simply
            not occur as the length of a string (of which the data
            includes multiple). *Theoretically* they could of course,
            but practically the strings will never be that long.

            Also note that this token is negative, which I think
            furthermore helps reduce/negate the possibility of
            collision. Furthermore it has fairly large components
            both when interpreted as positive and negative so I'm
            not sure that its value would ever cause a collision.
        */
        private static const VERIFCATION_TOKEN: * = int(0xAABBCCDD);

        private var final_loader: Loader;
        private var connection_class_info: *;

        private var server_address: String;

        private var handshake_secrets: * = null;

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
                which will keep track of the sent packets for us.
            */
            instance[socket_prop_name] = new ServerboundLeakerSocket(this.on_sent_packet);

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

        private function get_handle_packet_func() : Function {
            var game: * = (this.final_loader.content as DisplayObjectContainer).getChildAt(0) as Loader;

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

                /* The packet handler class is the only one with a static const 'Loader' attribute. */
                var constants: * = description.elements("constant");
                if (constants.length() != 1) {
                    continue;
                }

                if (constants[0].attribute("type") != "flash.display::Loader") {
                    continue;
                }

                for each (var method: * in description.elements("method")) {
                    if (method.attribute("returnType") != "void") {
                        continue;
                    }

                    var parameters: * = method.elements("parameter");
                    if (parameters.length() != 1) {
                        continue;
                    }

                    if (parameters[0].attribute("type") == "flash.utils::ByteArray") {
                        return klass[method.attribute("name")];
                    }
                }
            }

            return null;
        }

        private static const XXTEA_DELTA: uint = 0x9E3779B9;

        private static function XXTEA_MX(e: uint, p: uint, y: uint, z: uint, sum: uint, key: Array) : uint {
            /* Even though these are all 'uint', we still need to use '>>>'. This language sucks. */
            return (((z >>> 5) ^ (y << 2)) + ((y >>> 3) ^ (z << 4))) ^ ((sum ^ y) + (key[(p & 3) ^ e] ^ z));
        }

        private static function xxtea_decipher(buffer: ByteArray, key: Array) : ByteArray {
            var n: uint = buffer.readUnsignedShort();
            if (n == 1) {
                return buffer;
            }

            var blocks: * = new Array();
            for (var i: uint = 0; i < n; ++i) {
                blocks.push(buffer.readUnsignedInt());
            }

            --n;

            var y: uint = blocks[0];

            var cycles: uint = uint(6 + 52 / (n + 1));
            var sum: uint = cycles * XXTEA_DELTA;

            while (sum > 0) {
                var e: uint = (sum >> 2) & 3;

                for (var p: uint = n; p > 0; --p) {
                    var z: uint = blocks[p - 1];

                    blocks[p] -= XXTEA_MX(e, p, y, z, sum, key);
                    y = blocks[p];
                }

                var last_z: uint = blocks[n];

                blocks[0] -= XXTEA_MX(e, 0, y, last_z, sum, key);
                y = blocks[0];

                sum -= XXTEA_DELTA;
            }

            var deciphered_buffer: * = new ByteArray();

            for each (var block: uint in blocks) {
                deciphered_buffer.writeUnsignedInt(block);
            }

            deciphered_buffer.position = 0;

            return deciphered_buffer;
        }

        private static function key_from_name(name: String, packet_key_sources: Array) : Array {
            var num: int = 0x1505;

            for (var i: uint = 0; i < packet_key_sources.length; ++i) {
                var source_num: * = packet_key_sources[i];

                num = (num << 5) + num + source_num + name.charCodeAt(i % name.length);
            }

            var key: * = new Array();

            for each (var _: * in packet_key_sources) {
                num ^= (num << 13);
                num ^= (num >> 17);
                num ^= (num << 5);

                key.push(num);
            }

            return key;
        }

        private function on_sent_packet(data: ByteArray) : void {
            if (this.handshake_secrets == null) {
                this.handshake_secrets = this.get_handshake_secrets(data);

                var handle_packet_func: * = this.get_handle_packet_func();

                var client_verification_packet: * = new ByteArray();

                client_verification_packet.writeByte(176);
                client_verification_packet.writeByte(7);

                client_verification_packet.writeInt(VERIFCATION_TOKEN);

                handle_packet_func(client_verification_packet);

                return;
            }

            /* At this point 'data' is the serverbound client verification packet. */

            var game:     * = (this.final_loader.content as DisplayObjectContainer).getChildAt(0) as Loader;
            var document: * = game.getChildAt(0);

            var auth_key:           * = this.get_auth_key(document);
            var packet_key_sources: * = this.get_packet_key_sources(document);

            /* Read the packet ID. Will be (176, 47). */
            data.readUnsignedByte();
            data.readUnsignedByte();

            var key: * = key_from_name(VERIFCATION_TOKEN + "", packet_key_sources);

            var deciphered: * = xxtea_decipher(data, key);

            var string_data: * = "";
            while (deciphered.bytesAvailable) {
                var byte: * = deciphered.readUnsignedByte();

                if (byte < 0x10) {
                    string_data += "0";
                }

                string_data += byte.toString(16);
            }

            trace("Server Address:              ", this.server_address);
            trace("Game Version:                ", this.handshake_secrets.game_version);
            trace("Connection Token:            ", this.handshake_secrets.connection_token);
            trace("Auth Key:                    ", auth_key);
            trace("Packet Key Sources:          ", packet_key_sources);
            trace("Client Verification Template:", string_data);

            fscommand("quit");
        }
    }
}
