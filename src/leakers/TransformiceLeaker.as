package leakers {
    import flash.utils.describeType;
    import flash.net.Socket;

    public class TransformiceLeaker extends Leaker {
        private var socket_key_name:  String = null;
        private var socket_dict_name: String = null;

        public function TransformiceLeaker() {
            super("http://www.transformice.com/Transformice.swf", true);
        }

        protected override function process_socket_class(klass: Class) : void {
            var description: * = describeType(klass);

            for each (var variable: * in description.elements("factory").elements("variable")) {
                if (variable.attribute("type") == "Number") {
                    this.socket_key_name = variable.attribute("name");
                } else {
                    this.socket_dict_name = variable.attribute("name");
                }
            }
        }

        protected override function get_connection_socket(instance: *) : Socket {
            var adaptor: * = instance[this.connection_class_info.socket_prop_name];

            return adaptor[this.socket_dict_name][int(adaptor[this.socket_key_name])];
        }

        protected override function set_connection_socket(instance: *, socket: Socket) : void {
            var adaptor: * = instance[this.connection_class_info.socket_prop_name];

            adaptor[this.socket_dict_name][int(adaptor[this.socket_key_name])] = socket;
        }

        protected override function auth_key_return() : String {
            return "*";
        }
    }
}
