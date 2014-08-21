enum Chank {
  IHDR("49484452"), 
  IDAT("49444154"), 
  IEND("49454e44"), 
  tEXt("74455874"), 
  iTXt("69545874"), 
  unknown("");

  private String hex;

  Chank(String hex) {
    this.hex = hex;
  }

  public String getHex() {
    return hex;
  }
}

