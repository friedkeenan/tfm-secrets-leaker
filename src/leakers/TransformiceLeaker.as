package leakers {
    import flash.utils.describeType;
    import flash.net.Socket;

    public class TransformiceLeaker extends Leaker {
        private var real_socket_prop_name: String = null;

        public function TransformiceLeaker() {
            super("http://www.transformice.com/Transformice.swf", true);
        }

        protected override function process_socket_class(klass: Class) : void {
            var description: * = describeType(klass);

            for each (var variable: * in description.elements("factory").elements("variable")) {
                if (variable.attribute("type") == "flash.net::Socket") {
                    this.real_socket_prop_name = variable.attribute("name");

                    return;
                }
            }
        }

        protected override function get_connection_socket(instance: *) : Socket {
            return instance[this.connection_class_info.socket_prop_name][this.real_socket_prop_name];
        }

        protected override function set_connection_socket(instance: *, socket: Socket) : void {
            instance[this.connection_class_info.socket_prop_name][this.real_socket_prop_name] = socket;
        }

        protected override function auth_key_return() : String {
            return "*";
        }
    }
}
