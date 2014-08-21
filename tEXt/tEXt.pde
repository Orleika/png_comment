import java.io.UnsupportedEncodingException;
import java.util.zip.CRC32;
import javax.xml.bind.DatatypeConverter;

static final String PNG_FILE_SIGNATURE = "89504e470d0a1a0a";

static final int FILE_SIGNATURE_SIZE = 8;

static final int LENGTH_SIZE = 4;
static final int CHANK_TYPE_SIZE = 4;
static final int CRC_SIZE = 4;

void setup () {
  byte b[] = loadBytes("a_c.png");
  String[] comment;

  comment = readPngComment(b);
  for (int i = 0; i < comment.length; i++) {
    println(comment[i]);
  }
}

void loop() {
}

String[] readPngComment(byte[] b) {
  int idx = 0;
  ArrayList<String> comment = new ArrayList<String>();

  String str = readAsHexString(b, idx, FILE_SIGNATURE_SIZE);
  if (!isPng(str)) {
    println("ERROR: This file is broken, or not PNG.");
    return null;
  } else {
    idx += FILE_SIGNATURE_SIZE;
  }

  int length = -1;
  Chank iChankType;
  byte[] idata;

  while (0 <= idx) {
    length = readChankDataLength(b, idx);
    iChankType = readChankType(b, idx + LENGTH_SIZE);
    switch (iChankType) {
    case IHDR:
      break;
    case IDAT:
      break;
    case IEND:
      idx = -1;
      break;
    case tEXt:
      idata = readtEXt(b, idx, length);
      try {
        comment.add(new String(idata, "ISO-8859-1"));
      } 
      catch (UnsupportedEncodingException e) {
        println(e);
      }
      break;
    case iTXt:
      idata = readiTXt(b, idx, length);
      try {
        comment.add(new String(idata, "UTF-8"));
      } 
      catch (UnsupportedEncodingException e) {
        println(e);
      }
      break;
    default:
      break;
    }
    if (0 <= idx) {
      int chankSize = LENGTH_SIZE + CHANK_TYPE_SIZE + length + CRC_SIZE;
      idx += chankSize;
    }
  }

  return ((String[])comment.toArray(new String[0]));
}

String readAsHexString(byte[] bytes, int init_idx, int length) {
  StringBuffer strbuf = new StringBuffer(length);
  for (int i = init_idx; i < (init_idx + length); i++) {
    int bt = bytes[i] & 0xff;
    if (bt < 0x10) {
      strbuf.append("0");
    }
    strbuf.append(Integer.toHexString(bt));
  }
  return strbuf.toString();
}

int readAsInt(byte[] bytes, int init_idx, int length) {
  String hexStr = readAsHexString(bytes, init_idx, length);
  return Integer.parseInt(hexStr, 16);
}

long readAsLong(byte[] bytes, int init_idx, int length) {
  String hexStr = readAsHexString(bytes, init_idx, length);
  return Long.parseLong(hexStr, 16);
}

boolean isPng(String signatureHexStr) {
  return signatureHexStr.equals(PNG_FILE_SIGNATURE);
}

int getChankDataPosition(int idx) {
  return idx + LENGTH_SIZE + CHANK_TYPE_SIZE;
}

int readChankDataLength(byte[] bytes, int idx) {
  return readAsInt(bytes, idx, LENGTH_SIZE);
}

Chank readChankType(byte[] bytes, int idx) {
  String sChankType = readAsHexString(bytes, idx, CHANK_TYPE_SIZE);

  for (Chank c : Chank.values ()) {
    if (sChankType.equals(c.getHex())) {
      return c;
    }
  }
  return Chank.unknown;
}

byte[] readtEXt(byte[] bytes, int idx, int length) {
  byte[] chankData = new byte[length];
  int dataPos = getChankDataPosition(idx);
  arrayCopy(bytes, dataPos, chankData, 0, length);

  long crc = readAsLong(bytes, dataPos + length, CRC_SIZE);
  boolean valid = verifyCRC(DatatypeConverter.parseHexBinary(Chank.tEXt.getHex()), chankData, crc);
  if (!valid) { 
    println("WARN: tEXt CRC is not valid.");
  }

  return chankData;
}

byte[] readiTXt(byte[] bytes, int idx, int length) {
  byte[] chankData = new byte[length];
  int dataPos = getChankDataPosition(idx);
  arrayCopy(bytes, dataPos, chankData, 0, length);

  long crc = readAsLong(bytes, dataPos + length, CRC_SIZE);
  boolean valid = verifyCRC(DatatypeConverter.parseHexBinary(Chank.iTXt.getHex()), chankData, crc);
  if (!valid) { 
    println("WARN: iTXt CRC is not valid.");
  }

  return chankData;
}

boolean verifyCRC(byte[] typeBytes, byte[] data, long crc) {
  CRC32 crc32 = new CRC32();
  crc32.update(typeBytes);
  crc32.update(data);
  long calculated = crc32.getValue();
  return (calculated == crc);
}

