package leakers {
    public class TransformiceLeaker extends Leaker {
        public function TransformiceLeaker() {
            super("http://www.transformice.com/Transformice.swf", true);
        }

        protected override function auth_key_return() : String {
            return "*";
        }
    }
}
