package leakers {
    import flash.utils.describeType;
    import flash.net.Socket;
    import flash.utils.Dictionary;

    public class TransformiceLeaker extends Leaker {
        private var socket_dict_name: String;

        public function TransformiceLeaker() {
            super("http://www.transformice.com/Transformice.swf", true);
        }

        protected override function get_socket_info(_: XML) : void {
            var document:    * = this.document();
            var description: * = describeType(document);

            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") != "*") {
                    continue;
                }

                var maybe_dictionary: * = document[variable.attribute("name")];

                if (!(maybe_dictionary is Dictionary)) {
                    continue;
                }

                this.socket_dict_name = variable.attribute("name");

                return;
            }
        }

        protected override function get_connection_socket(instance: *) : Socket {
            return this.document()[this.socket_dict_name][1];
        }

        protected override function set_connection_socket(instance: *, socket: Socket) : void {
            this.document()[this.socket_dict_name][1] = socket;
        }

        protected override function auth_key_return() : String {
            return "*";
        }
    }
}
