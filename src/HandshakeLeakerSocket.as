package {
    import flash.net.Socket;
    import flash.utils.ByteArray;

    public class HandshakeLeakerSocket extends Socket {
        private var flush_callback: Function;
        private var written_bytes:  ByteArray = new ByteArray();

        public function HandshakeLeakerSocket(flush_callback: Function) {
            this.flush_callback = flush_callback;
        }

        /* NOTE: We only override the methods that we need to in order to get to the handshake packet. */

        public override function get connected() : Boolean {
            /* Just always report that we're connected. Makes things faster too. */

            return true;
        }

        public override function writeBytes(bytes: ByteArray, offset: uint = 0, length: uint = 0) : void {
            /*
                NOTE: We clear the buffer because we don't need the
                length and fingerprint data, just the body of the
                handshake packet, which is the second (and last)
                call to this method.
            */
            this.written_bytes.clear();
            this.written_bytes.writeBytes(bytes, offset, length);

            this.written_bytes.position = 0;
        }

        public override function flush() : void {
            this.flush_callback(this.written_bytes);
        }
    }
}