package {
    public class InvalidGameError extends Error {
        public function InvalidGameError(game: String) {
            super("Cannot leak secrets of specified game: " + game);
        }
    }
}
