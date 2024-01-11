package leakers {
    import flash.utils.describeType;
    import flash.net.Socket;

    public class TransformiceLeaker extends Leaker {
        public function TransformiceLeaker() {
            super("http://www.transformice.com/Transformice.swf", true);
        }

        protected override function is_socket_class(klass: Class) : Boolean {
            var description: * = describeType(klass);

            for each (var method: * in description.elements("factory").elements("method")) {
                if (method.attribute("returnType") == "flash.net::Socket") {
                    return true;
                }
            }

            return false;
        }

        protected override function get_connection_socket(instance: *) : Socket {
            var adaptor: * = instance[this.connection_class_info.socket_prop_name];

            for each (var dict: * in adaptor) {
                for each (var socket: * in dict) {
                    if (socket is Socket) {
                        return socket;
                    }
                }
            }

            return null;
        }

        protected override function set_connection_socket(instance: *, socket: Socket) : void {
            var adaptor: * = instance[this.connection_class_info.socket_prop_name];

            for each (var dict: * in adaptor) {
                for (var key: * in dict) {
                    if (dict[key] is Socket) {
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
