package leakers {
    import flash.utils.describeType;
    import flash.net.Socket;
    import flash.system.ApplicationDomain;
    import flash.utils.getQualifiedClassName;

    public class TransformiceLeaker extends Leaker {
        private var socket_dict_name: String;

        public function TransformiceLeaker() {
            super("http://www.transformice.com/Transformice.swf", true);
        }

        private function get_socket_prop_name(description: XML, type_name: String) : void {
            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") == type_name) {
                    this.socket_prop_name = variable.attribute("name");

                    return;
                }
            }
        }

        private function call_socket_method(domain: ApplicationDomain, description: XML, key: int) : Socket {
            var document: * = this.document();

            for each (var method: * in description.elements("method")) {
                if (method.elements("parameter").length() != 0) {
                    continue;
                }

                if (method.attribute("returnType") != "*") {
                    continue;
                }

                try {
                    return document[method.attribute("name")](key);
                } catch (error: Error) {
                    /* ... */
                }
            }

            return null;
        }

        protected override function process_connection_info(domain: ApplicationDomain, _: XML) : void {
            var document:    * = this.document();
            var description: * = describeType(document);

            /* Load a socket into the dictionary. */
            var real_socket: * = this.call_socket_method(domain, description, -1);

            var socket_type_name: * = getQualifiedClassName(real_socket);
            this.build_leaker_socket(domain, socket_type_name);

            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") != "flash.utils::Dictionary") {
                    continue;
                }

                var dictionary: * = document[variable.attribute("name")];

                if (dictionary == null) {
                    continue;
                }

                var maybe_socket: * = dictionary[-1];
                if (maybe_socket == null) {
                    continue;
                }

                if (maybe_socket is Socket) {
                    delete dictionary[-1];

                    this.socket_dict_name = variable.attribute("name");

                    this.get_socket_prop_name(describeType(maybe_socket), socket_type_name);

                    return;
                }
            }
        }

        protected override function get_connected_address(instance: *) : String {
            var description: * = describeType(instance);

            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") != "String") {
                    continue;
                }

                var value: * = instance[variable.attribute("name")];

                if (value != "_nfs_801") {
                    return value;
                }
            }

            return null;
        }

        protected override function get_connection_socket(instance: *) : Socket {
            for each (var socket: * in this.document()[this.socket_dict_name]) {
                return socket[this.socket_prop_name];
            }

            return null;
        }

        protected override function set_connection_socket(instance: *, socket: Socket) : void {
            var dictionary: * = this.document()[this.socket_dict_name];

            for (var key: * in dictionary) {
                dictionary[key][this.socket_prop_name] = socket;

                return;
            }
        }

        protected override function auth_key_return() : String {
            return "*";
        }
    }
}
