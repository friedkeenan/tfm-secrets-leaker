package leakers {
    import flash.utils.describeType;
    import flash.net.Socket;
    import flash.system.ApplicationDomain;

    public class TransformiceLeaker extends Leaker {
        private var socket_dict_name: String;

        public function TransformiceLeaker() {
            super("http://www.transformice.com/Transformice.swf", true);
        }

        private function is_socket_class(klass: Class) : Boolean {
            var description: * = describeType(klass);

            for each (var parent: * in description.elements("factory").elements("extendsClass")) {
                if (parent.attribute("type") == "flash.net::Socket") {
                    return true;
                }
            }

            return false;
        }

        private function get_socket_method_name(domain: ApplicationDomain, description: XML) : String {
            for each (var method: * in description.elements("method")) {
                try {
                    var return_type: * = domain.getDefinition(method.attribute("returnType"));
                } catch (ReferenceError) {
                    continue;
                }

                if (this.is_socket_class(return_type)) {
                    this.build_leaker_socket(domain, method.attribute("returnType"));

                    return method.attribute("name");
                }
            }

            return null;
        }

        protected override function process_socket_info(domain: ApplicationDomain, _: XML) : void {
            var document:    * = this.document();
            var description: * = describeType(document);

            var socket: * = document[this.get_socket_method_name(domain, description)](-1);

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
