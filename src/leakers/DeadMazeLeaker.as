package leakers {
    public class DeadMazeLeaker extends TransformiceLeaker {
        public function DeadMazeLeaker() {
            super("http://www.deadmaze.com/alpha/deadmeat.swf");
        }

        protected override function clientbound_client_verification_id() : Array {
            return new Array(176, 7);
        }
    }
}
