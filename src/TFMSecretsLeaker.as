package {
    import flash.display.Sprite;
    import flash.utils.Dictionary;
    import leakers.TransformiceLeaker;
    import leakers.DeadMazeLeaker;
    import leakers.NekodancerLeaker;
    import leakers.BouboumLeaker;
    import leakers.FortoresseLeaker;

    public class TFMSecretsLeaker extends Sprite {
        private static const GAME_TO_LEAKER: * = new Dictionary();

        {
            GAME_TO_LEAKER["bouboum"]      = BouboumLeaker;
            GAME_TO_LEAKER["deadmaze"]     = DeadMazeLeaker;
            GAME_TO_LEAKER["fortoresse"]   = FortoresseLeaker;
            GAME_TO_LEAKER["nekodancer"]   = NekodancerLeaker;
            GAME_TO_LEAKER["transformice"] = TransformiceLeaker;
        }

        public function TFMSecretsLeaker() {
            var game: * = root.loaderInfo.parameters.game as String;

            var leaker: * = null;
            if (game == null) {
                leaker = new TransformiceLeaker();
            } else {
                var leaker_class: * = GAME_TO_LEAKER[game];
                if (leaker_class == null) {
                    throw new InvalidGameError(game);
                }

                leaker = new leaker_class();
            }

            this.addChild(leaker);

            leaker.leak_secrets();
        }
    }
}
