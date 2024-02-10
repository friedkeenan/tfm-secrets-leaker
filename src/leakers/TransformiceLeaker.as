package leakers {
    import flash.utils.describeType;
    import flash.net.Socket;

    public class TransformiceLeaker extends Leaker {
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

            var main_socket: * = document[this.get_socket_method_name(description)](1);

            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") != "flash.net::Socket") {
                    continue;
                }

                var socket: * = document[variable.attribute("name")];

                if (socket != main_socket) {
                    continue;
                }

                this.socket_prop_name = variable.attribute("name");

                return;
            }
        }

        protected override function get_connection_socket(instance: *) : Socket {
            return this.document()[this.socket_prop_name];
        }

        protected override function set_connection_socket(instance: *, socket: Socket) : void {
            this.document()[this.socket_prop_name] = socket;
        }

        protected override function auth_key_return() : String {
            return "*";
        }
    }
}
