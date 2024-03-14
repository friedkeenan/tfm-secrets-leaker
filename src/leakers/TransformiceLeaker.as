package leakers {
    import flash.utils.describeType;
    import flash.net.Socket;

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

        protected override function get_socket_info(_: XML) : void {
            var document:    * = this.document();
            var description: * = describeType(document);

            var socket: * = document[this.get_socket_method_name(description)](-1);

            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") != "flash.utils::Dictionary") {
                    continue;
                }

                var dictionary: * = document[variable.attribute("name")];

                if (dictionary == null) {
                    continue;
                }

                if (dictionary[-1] == socket) {
                    delete dictionary[-1];

                    this.socket_dict_name = variable.attribute("name");

                    return;
                }
            }
        }

        protected override function get_connection_socket(instance: *) : Socket {
            for each (var socket: * in this.document()[this.socket_dict_name]) {
                return socket;
            }

            return null;
        }

        protected override function set_connection_socket(instance: *, socket: Socket) : void {
            var dictionary: * = this.document()[this.socket_dict_name];

            for (var key: * in dictionary) {
                dictionary[key] = socket;

                return;
            }
        }

        protected override function auth_key_return() : String {
            return "*";
        }
    }
}
