package leakers {
    import flash.utils.describeType;
    import flash.net.Socket;
    import flash.system.ApplicationDomain;

    public class TransformiceLeaker extends Leaker {
        private var socket_dict_name: String;

        public function TransformiceLeaker() {
            super("http://www.transformice.com/Transformice.swf", true);
        }

        private function get_socket_method_name(description: XML) : String {
            for each (var method: * in description.elements("method")) {
                if (method.attribute("returnType") == "flash.net::Socket") {
                    return method.attribute("name");
                }
            }

            return null;
        }

        private function get_socket_prop_name(description: XML) : void {
            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") == "flash.net::Socket") {
                    this.socket_prop_name = variable.attribute("name");

                    return;
                }
            }
        }

        protected override function process_socket_info(_: XML) : void {
            var document:    * = this.document();
            var description: * = describeType(document);

            /* Load a socket into the dictionary. */
            document[this.get_socket_method_name(description)](-1);

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

                    this.get_socket_prop_name(describeType(maybe_socket));

                    return;
                }
            }
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
