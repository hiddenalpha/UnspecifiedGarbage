package ch.hiddenalpha.unspecifiedgarbage.crypto;

import javax.crypto.Cipher;
import javax.crypto.CipherOutputStream;
import javax.crypto.NoSuchPaddingException;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.security.InvalidKeyException;
import java.security.KeyFactory;
import java.security.NoSuchAlgorithmException;
import java.security.spec.InvalidKeySpecException;
import java.security.spec.RSAPublicKeySpec;
import java.security.spec.X509EncodedKeySpec;

import static java.lang.System.err;
import static java.lang.System.in;
import static java.lang.System.out;


public class Foo {

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            err.println("\nUsage:\n  Pass path to public key as the only arg.\n  Then write to stdin and you'll get encrypted data on stdout.\n");
            System.exit(1);
        }
        var that = new Foo();
        that.encryptKey = args[0];
        try( var snk = that.newEncryptionFilter(out); ){
            byte[] buf = new byte[8192];
            while( true ){
                int readLen = in.read(buf, 0, buf.length);
                if( readLen == -1 ) break; /*EOF*/
                assert readLen > 0;
                snk.write(buf, 0, readLen);
            }
        }
    }

    private String encryptKey;

    private OutputStream newEncryptionFilter(OutputStream dst) throws IOException, NoSuchPaddingException, NoSuchAlgorithmException, InvalidKeySpecException, InvalidKeyException
    {
        byte[] rawKey;
        try (var is = new FileInputStream(encryptKey)) {
            rawKey = is.readAllBytes();
        }
        String algoStr = "RSA"/*TODO this info is available inside an PKCS8 file so take it from there automatically*/;
        var keySpec = new java.security.spec.PKCS8EncodedKeySpec(rawKey, algoStr);
        err.printf("format: %s\n", keySpec.getFormat());
        err.printf("algo: %s\n", keySpec.getAlgorithm());
        var keyFactory = KeyFactory.getInstance(keySpec.getAlgorithm());
        var key = keyFactory.generatePublic(keySpec);
        var cipher = Cipher.getInstance("AES");
        cipher.init(Cipher.ENCRYPT_MODE, key);
        return new CipherOutputStream(dst, cipher);
    }

}
