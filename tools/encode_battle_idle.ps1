param([string]$ReviewRoot)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Private.Windows.GdiPlus,System.Private.Windows.Core -TypeDefinition @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Imaging;
public static class SpriteGifPreview {
 public static void Build(string[] paths,string output) {
  using(var fs=File.Create(output))
  using(var w=new BinaryWriter(fs)) {
   using(var first=new Bitmap(paths[0])) {
    w.Write(System.Text.Encoding.ASCII.GetBytes("GIF89a"));
    w.Write((ushort)first.Width);w.Write((ushort)first.Height);
   }
   w.Write((byte)0x70);w.Write((byte)0);w.Write((byte)0);
   w.Write(new byte[]{0x21,0xff,11});
   w.Write(System.Text.Encoding.ASCII.GetBytes("NETSCAPE2.0"));
   w.Write(new byte[]{3,1,0,0,0});
   for(int n=0;n<paths.Length;n++) {
    byte[] bytes;
    using(var bm=new Bitmap(paths[n]))
    using(var ms=new MemoryStream()){bm.Save(ms,ImageFormat.Gif);bytes=ms.ToArray();}
    int p=13;int size=3*(1<<((bytes[10]&7)+1));
    var global=new byte[size];
    if((bytes[10]&128)!=0){Array.Copy(bytes,p,global,0,size);p+=size;}
    while(bytes[p]!=0x2c) {
     if(bytes[p]!=0x21)throw new Exception("Unexpected GIF block");
     p+=2;while(bytes[p]!=0){int len=bytes[p];p+=1+len;}p++;
    }
    w.Write(new byte[]{0x21,0xf9,4,4});
    w.Write((ushort)(5));
    w.Write((byte)0);w.Write((byte)0);
    w.Write((byte)0x2c);p++;
    w.Write(bytes,p,8);p+=8;
    byte packed=bytes[p++];
    if((packed&128)!=0){
     w.Write(packed);int count=3*(1<<((packed&7)+1));w.Write(bytes,p,count);p+=count;
    } else {
     w.Write((byte)(128|(bytes[10]&7)));w.Write(global);
    }
    w.Write(bytes[p++]);
    while(bytes[p]!=0){int len=bytes[p++];w.Write((byte)len);w.Write(bytes,p,len);p+=len;}
    p++;w.Write((byte)0);
   }
   w.Write((byte)0x3b);
  }
 }
}
'@
$frames = @(Get-ChildItem -LiteralPath $ReviewRoot -Filter 'idle-*.png' | Sort-Object Name | Select-Object -ExpandProperty FullName)
[SpriteGifPreview]::Build([string[]]$frames,(Join-Path $ReviewRoot 'battle-idle.gif'))
