
$pngood_version = '1.0.5';

=readme
    charset shift-jis
    /_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

    PNGooD
    LastModified : 2005-05/22
    Powered by kerry
    http://202.248.69.143/~goma/

    /_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

    @ Whats PNGooD

    PNG のコメントなどを削除してファイルサイズを小さくします。

    /_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/_/

  @ Usage

  # eXample;
  require "pngood.pl";
  $result = pngood::dieter( $pngFile [, $option [, $newFile ]] );

  * $pngFile

    操作したい PNG ファイルのパス。

  * $option


    @ 削除しても安全と思われる補助チャンクの削除

      通常はこのオプションを選択します。
      このオプションは必要最低限のチャンクのみを残し後は削除す
      るというものです。おそらく画像が表示できないということは
      ないでしょう。

      $option = 1;
      or
      $option = 'safe';

      $option に上記のどちらかの値を渡すと「複写安全ビット」が
      立っているチャンクを全て削除します。


    @ 補助チャンクを全て削除

      このオプションは必須チャンクのみを残し後は全て削除すると
      いうものです。必要な補助チャンクまで削除してしまうため
      デコーダによっては画像が描画されない可能性があります。

      $option = 2;
      or
      $option = 'all';

      $option に上記のどちらかの値を渡すと補助チャンクを全て
      削除します。
      ※ プライベート・チャンク が存在すれば削除されます。

    @ テキストチャンクの削除

      $option を省略するか上述の値以外ではこのモードになりま
      す。テキストチャンクのみ削除したい場合はこのモードです。

      e.g., $option = 'text';


  * $newFile

    操作済みデータをファイルに書き出す場合はそのファイルのパス。
    省略した場合は $result にデータが返ります。

  * $result

    $result には結果が返ります。

    @ エラーが起こったときは error という文字列が返ります。
    @ 削れるものが無かった時は数字の 0 が返ります。$newFile は
      作られません（正確には削除してます）。
    @ $newFile に書き出しを行なった場合は削ったバイト数が返りま
      す。$newFile を省略した場合は操作済みデータが返ります。


  @ コメントの埋め込み

  $result = pngood::inserter( $pngFile, $comment [, $newFile ]);

    * $comment は挿入したいコメント。
    * 成功時、$result には $newFile 省略時は挿入後のデータが返り、
      ファイル生成時には数字の 1 が返ります。



  @ PNG の簡単な解析

  # eXample;
  $result = pngood::analyzer( $pngFile );
  print $result;

=cut


package pngood;


sub dieter
{
  &check(@_) or return 'error';
  $analyz = 0;
  &bufOrOut or return 'error';
  &searchChunk;
  close PNG;

  if ($buffering)
  {
    if (!$error and (-s $file)- length($bufData))
    {
      return $bufData;
    }
    else
    {
      undef $bufData;
      return $error? 'error': 0;
    }
  }
  else
  {
    $ded = (-s $file)- (-s OUT);
    close OUT;
    if (!$error and $ded)
    {
      return $ded;
    }
    else
    {
      unlink $newFile;
      return $error? 'error': 0;
    }
  }
}

sub bufOrOut
{
  if ($newFile ne '')
  {
    open(OUT, "> $newFile") or return 0;
    binmode OUT;
    unless (print OUT $signature)
    {
      close OUT;
      return 0;
    }
    $buffering = 0;
    $bufData = 1;
  }
  else
  {
    $buffering = 1;
    $bufData = $signature;
  }
  1;
}

sub inserter
{
  &check(@_) or return 'error';
  &bufOrOut or return 'error';
  read PNG, $buf, 13+ 12;
  &xbuf;
  local($x) = int(length($option)/ 0xffff);
  $x += (length($option)/ 0xffff) <=> $x ;
  local($n) = 0;
  &crc32table;
  while ($n<$x)
  {
    $cmnt = "Comment\x00";
    $cmnt .= substr($option, $n++ * 0xffff, 0xffff);
    $buf = pack "N", length($cmnt);
    $cmnt = "tEXt". $cmnt;
    $buf .= $cmnt;
    $crc = 0xffffffff;
    &getCrc32;
    $buf .= pack "N", ~$crc;
    &xbuf;
  }
  undef $option;
  undef $cmnt;
  undef @table;
  &xbuf while (read PNG, $buf, $bufSize);
  close PNG;
  close OUT if !$buffering;
  return $bufData;
}

sub xbuf
{
  if ($buffering) {
    $bufData .= $buf;
  }
  else {
    print OUT $buf;
  }
  $buf = '';
}


sub analyzer
{
  $analyz = 1;
  $anaData = '';
  &check(@_) or return 'error1';
  &searchChunk;
  if ($error) {
    $anaData .= sprintf "\nError: %d [%#02x %#02x %#02x %#02x]\n",
      tell(PNG)- 8, unpack("C4", $buf);
  }
  close PNG;
  return $anaData;
}

sub check
{
  ($file, $option, $newFile) = @_;
  $sigSize = 8;
  $bufSize = 1024;

  if (open PNG, $file)
  {
    binmode PNG;
    if (read(PNG, $signature, $sigSize) and $signature eq "\x89PNG\x0d\x0a\x1a\x0a")
    {
      return 1;
    }
    close PNG;
  }
  return 0;
}


sub searchChunk
{
  # Big-endian
  # ChunkLayout -> DataLength(4)+ Chunk(4)+ Data(n)+ CRC(4)

  $crcLength = 4;

  if ($option == 1 or $option =~ /^safe$/i)
  {
    $reg = q#[a-z]..[a-z]#;         # safe bit
  }
  elsif ($option == 2 or $option =~ /^all$/i)
  {
    $reg = q#[a-z]...|.[a-z]..#;      # sub + private
  }
  else
  {
    $reg = q#iTXt|tEXt|zTXt#;       # text
  }

  while (read PNG, $buf, 8) # 8 = DataSize(4)+ Chunk(4)
  {
    $dataSize = unpack "N", $buf;
    $chunk = substr $buf, 4;  # 4 = Chunk Length

    if ($chunk =~ /[^a-zA-Z]/)
    {
      $error = 1;
      last;
    }
    elsif ($analyz)
    {
      &analyz__;
    }
    else
    {
      &diet__;
    }

    if ($chunk eq 'IEND')
    {
      last;
    }
  }
}


sub pngHdr
{
  $anaData .= sprintf "    %-15s: %d px\n", "ScreenWidth", unpack("N", substr($buf, 0, 4) );
  $anaData .= sprintf "    %-15s: %d px\n", "ScreenHeight", unpack("N", substr($buf, 4, 4) );
  $anaData .= sprintf "    %-15s: %d \n", "ColorResolution", unpack("C", substr($buf, 8, 1) );
  $anaData .= sprintf "    %-15s: %d \n", "ColorType", unpack("C", substr($buf, 9, 1) );
  $anaData .= sprintf "    %-15s: %d \n", "CompressionType", unpack("C", substr($buf, 10, 1) );
  $anaData .= sprintf "    %-15s: %d \n", "FilterType", unpack("C", substr($buf, 11, 1) );
  $anaData .= sprintf "    %-15s: %d \n", "InterraceType", unpack("C", substr($buf, 12, 1) );
  $anaData .= "\n";
}

sub analyz__
{
  $anaData .= sprintf "Chunk: %s -%6d byte\n", $chunk, $dataSize;
  if ($chunk eq 'IHDR')
  {
    read PNG, $buf, $dataSize+ $crcLength;
    &pngHdr;
    undef $buf;
  }
  elsif ($chunk eq 'tEXt')
  {
    read PNG, $buf, $dataSize;

    if ($buf =~ /\x00/) {
      $anaData .= sprintf "    %15s : %s \n", split(/\x00/, $buf, 2);
    }
    else {
      $anaData .= sprintf "    %-15s\n", $buf;
    }
    $anaData .= "\n";
    seek PNG, $crcLength, 1;
  }
  else
  {
    seek PNG, $dataSize+$crcLength, 1;
    if ($chunk eq 'IEND' and (-s PNG) != tell(PNG)) {
      $anaData .= sprintf ("Data that is behind 'IEND': %d byte",(-s PNG)- tell(PNG) );
    }
  }
}

sub diet__
{
  if ($chunk =~ /$reg/)
  {
    seek PNG, $dataSize+ $crcLength, 1;
  }
  else
  {
    if ($buffering)
    {
      read PNG, $buf, $dataSize+ $crcLength, 8; # 8 = length($buf)
      $bufData .= $buf;
    }
    else
    {
      print OUT $buf;
      $i = int(($dataSize+ $crcLength)/ $bufSize);
      while ($i--)
      {
        read PNG, $buf, $bufSize;
        print OUT $buf;
      }
      read PNG, $buf, ($dataSize+ $crcLength)% $bufSize;
      print OUT $buf;
    }
  }
}

sub getCrc32
{
    local($i) = 0;
    local($tm) = int( 0xffff / $bufSize );
    $tm += (0xffff / $bufSize) <=> $tm;

    while ($tm--)
    {
        $crc = $table[ ($crc ^ $_) & 0xff ] ^ ($crc >> 8)
            for unpack "C*", substr($cmnt, $i++ * $bufSize, $bufSize);
    }
}

sub crc32table
{
    @table = (
                 0 , 0x77073096 , 0xee0e612c , 0x990951ba ,  0x76dc419 , 0x706af48f , 0xe963a535 , 0x9e6495a3 ,
         0xedb8832 , 0x79dcb8a4 , 0xe0d5e91e , 0x97d2d988 ,  0x9b64c2b , 0x7eb17cbd , 0xe7b82d07 , 0x90bf1d91 ,
        0x1db71064 , 0x6ab020f2 , 0xf3b97148 , 0x84be41de , 0x1adad47d , 0x6ddde4eb , 0xf4d4b551 , 0x83d385c7 ,
        0x136c9856 , 0x646ba8c0 , 0xfd62f97a , 0x8a65c9ec , 0x14015c4f , 0x63066cd9 , 0xfa0f3d63 , 0x8d080df5 ,
        0x3b6e20c8 , 0x4c69105e , 0xd56041e4 , 0xa2677172 , 0x3c03e4d1 , 0x4b04d447 , 0xd20d85fd , 0xa50ab56b ,
        0x35b5a8fa , 0x42b2986c , 0xdbbbc9d6 , 0xacbcf940 , 0x32d86ce3 , 0x45df5c75 , 0xdcd60dcf , 0xabd13d59 ,
        0x26d930ac , 0x51de003a , 0xc8d75180 , 0xbfd06116 , 0x21b4f4b5 , 0x56b3c423 , 0xcfba9599 , 0xb8bda50f ,
        0x2802b89e , 0x5f058808 , 0xc60cd9b2 , 0xb10be924 , 0x2f6f7c87 , 0x58684c11 , 0xc1611dab , 0xb6662d3d ,

        0x76dc4190 ,  0x1db7106 , 0x98d220bc , 0xefd5102a , 0x71b18589 ,  0x6b6b51f , 0x9fbfe4a5 , 0xe8b8d433 ,
        0x7807c9a2 ,  0xf00f934 , 0x9609a88e , 0xe10e9818 , 0x7f6a0dbb ,  0x86d3d2d , 0x91646c97 , 0xe6635c01 ,
        0x6b6b51f4 , 0x1c6c6162 , 0x856530d8 , 0xf262004e , 0x6c0695ed , 0x1b01a57b , 0x8208f4c1 , 0xf50fc457 ,
        0x65b0d9c6 , 0x12b7e950 , 0x8bbeb8ea , 0xfcb9887c , 0x62dd1ddf , 0x15da2d49 , 0x8cd37cf3 , 0xfbd44c65 ,
        0x4db26158 , 0x3ab551ce , 0xa3bc0074 , 0xd4bb30e2 , 0x4adfa541 , 0x3dd895d7 , 0xa4d1c46d , 0xd3d6f4fb ,
        0x4369e96a , 0x346ed9fc , 0xad678846 , 0xda60b8d0 , 0x44042d73 , 0x33031de5 , 0xaa0a4c5f , 0xdd0d7cc9 ,
        0x5005713c , 0x270241aa , 0xbe0b1010 , 0xc90c2086 , 0x5768b525 , 0x206f85b3 , 0xb966d409 , 0xce61e49f ,
        0x5edef90e , 0x29d9c998 , 0xb0d09822 , 0xc7d7a8b4 , 0x59b33d17 , 0x2eb40d81 , 0xb7bd5c3b , 0xc0ba6cad ,

        0xedb88320 , 0x9abfb3b6 ,  0x3b6e20c , 0x74b1d29a , 0xead54739 , 0x9dd277af ,  0x4db2615 , 0x73dc1683 ,
        0xe3630b12 , 0x94643b84 ,  0xd6d6a3e , 0x7a6a5aa8 , 0xe40ecf0b , 0x9309ff9d ,  0xa00ae27 , 0x7d079eb1 ,
        0xf00f9344 , 0x8708a3d2 , 0x1e01f268 , 0x6906c2fe , 0xf762575d , 0x806567cb , 0x196c3671 , 0x6e6b06e7 ,
        0xfed41b76 , 0x89d32be0 , 0x10da7a5a , 0x67dd4acc , 0xf9b9df6f , 0x8ebeeff9 , 0x17b7be43 , 0x60b08ed5 ,
        0xd6d6a3e8 , 0xa1d1937e , 0x38d8c2c4 , 0x4fdff252 , 0xd1bb67f1 , 0xa6bc5767 , 0x3fb506dd , 0x48b2364b ,
        0xd80d2bda , 0xaf0a1b4c , 0x36034af6 , 0x41047a60 , 0xdf60efc3 , 0xa867df55 , 0x316e8eef , 0x4669be79 ,
        0xcb61b38c , 0xbc66831a , 0x256fd2a0 , 0x5268e236 , 0xcc0c7795 , 0xbb0b4703 , 0x220216b9 , 0x5505262f ,
        0xc5ba3bbe , 0xb2bd0b28 , 0x2bb45a92 , 0x5cb36a04 , 0xc2d7ffa7 , 0xb5d0cf31 , 0x2cd99e8b , 0x5bdeae1d ,

        0x9b64c2b0 , 0xec63f226 , 0x756aa39c ,  0x26d930a , 0x9c0906a9 , 0xeb0e363f , 0x72076785 ,  0x5005713 ,
        0x95bf4a82 , 0xe2b87a14 , 0x7bb12bae ,  0xcb61b38 , 0x92d28e9b , 0xe5d5be0d , 0x7cdcefb7 ,  0xbdbdf21 ,
        0x86d3d2d4 , 0xf1d4e242 , 0x68ddb3f8 , 0x1fda836e , 0x81be16cd , 0xf6b9265b , 0x6fb077e1 , 0x18b74777 ,
        0x88085ae6 , 0xff0f6a70 , 0x66063bca , 0x11010b5c , 0x8f659eff , 0xf862ae69 , 0x616bffd3 , 0x166ccf45 ,
        0xa00ae278 , 0xd70dd2ee , 0x4e048354 , 0x3903b3c2 , 0xa7672661 , 0xd06016f7 , 0x4969474d , 0x3e6e77db ,
        0xaed16a4a , 0xd9d65adc , 0x40df0b66 , 0x37d83bf0 , 0xa9bcae53 , 0xdebb9ec5 , 0x47b2cf7f , 0x30b5ffe9 ,
        0xbdbdf21c , 0xcabac28a , 0x53b39330 , 0x24b4a3a6 , 0xbad03605 , 0xcdd70693 , 0x54de5729 , 0x23d967bf ,
        0xb3667a2e , 0xc4614ab8 , 0x5d681b02 , 0x2a6f2b94 , 0xb40bbe37 , 0xc30c8ea1 , 0x5a05df1b , 0x2d02ef8d ,
    );

}

1;