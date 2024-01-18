package leakers {
    import flash.utils.describeType;
    import flash.net.Socket;

    public class TransformiceLeaker extends Leaker {
        private var socket_getter: String = null;

        public function TransformiceLeaker() {
            super("http://www.transformice.com/Transformice.swf", true);
        }

        protected override function is_socket_class(klass: Class) : Boolean {
            var description: * = describeType(klass);

            for each (var method: * in description.elements("factory").elements("method")) {
                if (method.attribute("returnType") == "flash.net::Socket") {
                    this.socket_getter = method.attribute("name");

                    return true;
                }
            }

            return false;
        }

        protected override function get_connection_socket(instance: *) : Socket {
            var adaptor: * = instance[this.connection_class_info.socket_prop_name];

            return adaptor[this.socket_getter]();
        }

        protected override function set_connection_socket(instance: *, socket: Socket) : void {
            var adaptor: * = instance[this.connection_class_info.socket_prop_name];

            var old_socket: * = adaptor[this.socket_getter]();

            for each (var dict: * in adaptor) {
                for (var key: * in dict) {
                    if (dict[key] == old_socket) {
                        dict[key] = socket;

                        return;
                    }
                }
            }
        }

        protected override function auth_key_return() : String {
            return "*";
        }
    }
}
