import java.lang.reflect.*;
import java.util.*;
import java.nio.charset.StandardCharsets;
import java.io.File;

/** Read-only invocation of known pure algorithm methods from the reference APK. */
public class ApkAlgorithmProbe {
  static String quote(String text) {
    StringBuilder s = new StringBuilder("\"");
    for (char c : text.toCharArray()) {
      if (c == '"' || c == '\\') s.append('\\').append(c);
      else if (c < 32 || Character.isSurrogate(c)) s.append(String.format("\\u%04x", (int)c));
      else s.append(c);
    }
    return s.append('"').toString();
  }
  static String hex(byte[] bytes) {
    StringBuilder s=new StringBuilder();
    for(byte b:bytes)s.append(String.format("%02X",b&255));
    return s.toString();
  }
  public static void main(String[] args) throws Exception {
    File optimized = new File(args[1]); optimized.mkdirs();
    Class<?> dex = Class.forName("dalvik.system.DexClassLoader");
    ClassLoader loader = (ClassLoader)dex.getConstructor(String.class,String.class,String.class,ClassLoader.class)
      .newInstance(args[0],optimized.getAbsolutePath(),null,ApkAlgorithmProbe.class.getClassLoader());
    Class<?> codec = loader.loadClass("i4.a");
    Class<?> rc4 = loader.loadClass("w3.a");
    Method hexEncode=codec.getMethod("g2",String.class);
    Method hexDecode=codec.getMethod("F0",String.class);
    Method md5=codec.getMethod("b1",String.class,boolean.class,boolean.class);
    Method rc4Encode=rc4.getMethod("b",String.class,String.class);
    Method rc4Decrypt=rc4.getMethod("a",byte[].class,String.class);
    List<String> rows = new ArrayList<>();
    String[] texts={"abc","你好","Hello 世界😀","line1\nline2\t","A\u0000B","\\u41 & + / ?","12345678"};
    String[] keys={"12345678","中文密钥一二三四"};
    for(String key:keys)for(String text:texts) {
      String hx=(String)hexEncode.invoke(null,text);
      String back=(String)hexDecode.invoke(null,hx);
      if(!back.equals(text))throw new AssertionError("Original HEX roundtrip");
      byte[] encrypted=(byte[])rc4Encode.invoke(null,text,key);
      String decoded=new String((byte[])rc4Decrypt.invoke(null,encrypted,key),StandardCharsets.UTF_8);
      if(!decoded.equals(text))throw new AssertionError("Original RC4 roundtrip");
      int[] modes={0,8,9,10,11,12,13,14};
      String[] values={hx,(String)md5.invoke(null,text,true,false),(String)md5.invoke(null,text,false,false),
        (String)md5.invoke(null,text,true,true),(String)md5.invoke(null,text,false,true),hex(encrypted),
        Base64.getEncoder().encodeToString(encrypted),Arrays.toString(encrypted)};
      for(int i=0;i<modes.length;i++)rows.add("{\"mode\":"+modes[i]+",\"input\":"+quote(text)+
        ",\"key\":"+quote(key)+",\"expected\":"+quote(values[i])+",\"decoded\":"+quote(text)+"}");
    }
    System.out.println("{\"source\":\"Original APK pure methods via read-only DexClassLoader; UI not exercised\",\"vectors\":["+String.join(",",rows)+"]}");
  }
}