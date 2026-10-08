import javax.crypto.Cipher;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.DESKeySpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.Charset;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.*;

public class ReferenceVectors {
  static String quote(String text) {
    StringBuilder s = new StringBuilder("\"");
    for (char c : text.toCharArray()) {
      if (c == '"' || c == '\\') { s.append('\\').append(c); }
      else if (c < 32 || Character.isSurrogate(c)) s.append(String.format("\\u%04x", (int)c));
      else s.append(c);
    }
    return s.append('"').toString();
  }
  static String hex(byte[] data) {
    StringBuilder s = new StringBuilder();
    for (byte b : data) s.append(String.format("%02X", b & 255));
    return s.toString();
  }
  static byte[] crypt(String alg, byte[] data, String key, int op) throws Exception {
    Cipher cipher = Cipher.getInstance(alg);
    if (alg.equals("DES")) cipher.init(op, SecretKeyFactory.getInstance("DES").generateSecret(
        new DESKeySpec(key.getBytes(StandardCharsets.UTF_8))));
    else cipher.init(op, new SecretKeySpec(key.getBytes(StandardCharsets.UTF_8),"RC4"));
    return cipher.doFinal(data);
  }
  static String[] run(String text, String key) throws Exception {
    byte[] utf8 = text.getBytes(StandardCharsets.UTF_8);
    byte[] des = crypt("DES",utf8,key,Cipher.ENCRYPT_MODE);
    byte[] rc4 = crypt("RC4",utf8,key,Cipher.ENCRYPT_MODE);
    if (!Arrays.equals(utf8, crypt("DES",des,key,Cipher.DECRYPT_MODE)) ||
        !Arrays.equals(utf8, crypt("RC4",rc4,key,Cipher.DECRYPT_MODE))) throw new AssertionError("roundtrip");
    StringBuilder uni = new StringBuilder();
    for (char c : text.toCharArray()) uni.append("\\u").append(Integer.toHexString(c));
    String md5 = hex(MessageDigest.getInstance("MD5").digest(utf8));
    return new String[]{hex(utf8),Base64.getEncoder().encodeToString(utf8),Arrays.toString(utf8),
      Arrays.toString(text.getBytes(Charset.forName("GBK"))), uni.toString(),
      Base64.getEncoder().encodeToString(des),hex(des),Arrays.toString(des),
      md5,md5.toLowerCase(Locale.ROOT),md5.substring(8,24),md5.substring(8,24).toLowerCase(Locale.ROOT),
      hex(rc4),Base64.getEncoder().encodeToString(rc4),Arrays.toString(rc4)};
  }
  public static void main(String[] args) throws Exception {
    List<String> rows = new ArrayList<>();
    String[] texts = {"abc","你好","Hello 世界😀","line1\nline2\t","A\u0000B","\\u41 & + / ?","12345678"};
    String[] keys = {"12345678","中文密钥一二三四"};
    for (String key : keys) for (String text : texts) {
      String[] values = run(text,key);
      for (int mode=0;mode<values.length;mode++) {
        String decoded = mode == 3 ? new String(text.getBytes("GBK"),"GBK") : text;
        rows.add("{\"mode\":"+mode+",\"input\":"+quote(text)+",\"key\":"+quote(key)+
          ",\"expected\":"+quote(values[mode])+",\"decoded\":"+quote(decoded)+"}");
      }
    }
    System.out.println("{\"source\":\"OpenJDK JCE independent reference; not APK output\",\"provider\":"+
      quote(Cipher.getInstance("DES").getProvider().getName())+",\"vectors\":["+String.join(",",rows)+"]}");
  }
}
