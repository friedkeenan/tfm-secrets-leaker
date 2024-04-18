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

        private static function extends_socket(domain: ApplicationDomain, type: Class) : Boolean {
            if (type == Socket) {
                return true;
            }

            var description: * = describeType(type);

            for each (var parent: * in description.elements("factory").elements("extendsClass")) {
                var parent_type: * = domain.getDefinition(parent.attribute("type"));

                if (extends_socket(domain, parent_type)) {
                    return true;
                }
            }

            return false;
        }

        private function get_socket_method_name(domain: ApplicationDomain, description: XML) : String {
            for each (var method: * in description.elements("method")) {
                if (method.elements("parameter").length() != 0) {
                    continue;
                }

                var return_type_name: * = method.attribute("returnType");
                if (return_type_name == "void" || return_type_name == "*") {
                    continue;
                }

                var return_type: * = domain.getDefinition(return_type_name);
                if (!extends_socket(domain, return_type)) {
                    continue;
                }

                this.build_leaker_socket(domain, return_type_name);

                return method.attribute("name");
            }

            return null;
        }

        private function get_socket_prop_name(description: XML, type_name: String) : void {
            for each (var variable: * in description.elements("variable")) {
                if (variable.attribute("type") == type_name) {
                    this.socket_prop_name = variable.attribute("name");

                    return;
                }
            }
        }

        protected override function process_socket_info(domain: ApplicationDomain, _: XML) : void {
            var document:    * = this.document();
            var description: * = describeType(document);

            /* Load a socket into the dictionary. */
            var real_socket: * = document[this.get_socket_method_name(domain, description)](-1);

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

                    this.get_socket_prop_name(describeType(maybe_socket), getQualifiedClassName(real_socket));

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
