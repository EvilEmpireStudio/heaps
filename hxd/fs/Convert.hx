package hxd.fs;

class Convert {

	public var sourceExt(default,null) : String;
	public var destExt(default,null) : String;

	public var srcPath : String;
	public var dstPath : String;
	public var srcFilename : String;
	public var srcBytes : haxe.io.Bytes;

	public function new( sourceExt, destExt ) {
		this.sourceExt = sourceExt;
		this.destExt = destExt;
	}

	public function convert() {
		throw "Not implemented";
	}

	function save( bytes : haxe.io.Bytes ) {
		hxd.File.saveBytes(dstPath, bytes);
	}

	function command( cmd : String, args : Array<String> ) {
		#if flash
		trace("TODO");
		#elseif sys
		var code = Sys.command(cmd, args);
		if( code != 0 )
			throw "Command '" + cmd + (args.length == 0 ? "" : " " + args.join(" ")) + "' failed with exit code " + code;
		#else
		throw "Don't know how to run command on this platform";
		#end
	}

}

class ConvertFBX2HMD extends Convert {

	public function new() {
		super("fbx", "hmd");
	}

	override function convert() {
		var fbx = try hxd.fmt.fbx.Parser.parse(srcBytes) catch( e : Dynamic ) throw Std.string(e) + " in " + srcPath;
		var hmdout = new hxd.fmt.fbx.HMDOut(srcPath);
		hmdout.load(fbx);
		var isAnim = StringTools.startsWith(srcFilename, "Anim_") || srcFilename.toLowerCase().indexOf("_anim_") > 0;
		var hmd = hmdout.toHMD(null, !isAnim);
		var out = new haxe.io.BytesOutput();
		new hxd.fmt.hmd.Writer(out).write(hmd);
		save(out.getBytes());
	}

}

class Command extends Convert {

	var cmd : String;
	var args : Array<String>;

	public function new(fr,to,cmd:String,args:Array<String>) {
		super(fr,to);
		this.cmd = cmd;
		this.args = args;
	}

	override function convert() {
		command(cmd,[for( a in args ) if( a == "%SRC" ) srcPath else if( a == "%DST" ) dstPath else a]);
	}

}


class ConvertWAV2MP3 extends Convert {

	public function new() {
		super("wav", "mp3");
	}

	override function convert() {
		command("lame", ["--resample", "44100", "--silent", "-h", srcPath, dstPath]);
	}

}

class ConvertWAV2OGG extends Convert {

	public function new() {
		super("wav", "ogg");
	}

	override function convert() {
		var cmd = "oggenc";
		#if (sys || nodejs)
		if( Sys.systemName() == "Windows" ) cmd = "oggenc2";
		#end
		command(cmd, ["--resample", "44100", "-Q", srcPath, "-o", dstPath]);
	}

}

class ConvertTGA2PNG extends Convert {

	public function new() {
		super("tga", "png");
	}

	override function convert() {
		#if (sys || nodejs)
		var input = new haxe.io.BytesInput(sys.io.File.getBytes(srcPath));
		var r = new format.tga.Reader(input).read();
		if( r.header.imageType != UncompressedTrueColor || r.header.bitsPerPixel != 32 )
			throw "Not supported "+r.header.imageType+"/"+r.header.bitsPerPixel;
		var w = r.header.width;
		var h = r.header.height;
		var pix = hxd.Pixels.alloc(w, h, ARGB);
		var access : hxd.Pixels.PixelsARGB = pix;
		var p = 0;
		for( y in 0...h )
			for( x in 0...w ) {
				var c = r.imageData[x + y * w];
				access.setPixel(x, y, c);
			}
		switch( r.header.imageOrigin ) {
		case BottomLeft:
			pix.flags.set(FlipY);
		case TopLeft:
		default:
			throw "Not supported "+r.header.imageOrigin;
		}
		sys.io.File.saveBytes(dstPath, pix.toPNG());
		#else
		throw "Not implemented";
		#end
	}

}

class ConvertFNT2BFNT extends Convert {
	
	var emptyTile : h2d.Tile;
	
	public function new() {
		// Fake tile create subs before discarding the font.
		emptyTile = @:privateAccess new h2d.Tile(null, 0, 0, 0, 0, 0, 0);
		super("fnt", "bfnt");
	}
	
	override public function convert()
	{
		var font = hxd.fmt.bfnt.FontParser.parse(srcBytes, srcPath, resolveTile);
		var out = new haxe.io.BytesOutput();
		new hxd.fmt.bfnt.Writer(out).write(font);
		save(out.getBytes());
	}
	
	function resolveTile( path : String ) : h2d.Tile {
		#if sys
		if (!sys.FileSystem.exists(path)) throw "Could not resolve BitmapFont texture reference at path: " + path;
		#end
		return emptyTile;
	}
}

class ConvertPNGtoEEF extends Convert {
	var compressLevel : Int;
	var bWarn : Bool;

	public function new(complvl : Int) {
		super("png", "eef");
		compressLevel = complvl;
		bWarn = true;
	}

	static function getColorType(fileName : String) : Int {
		var fin = sys.io.File.read(fileName);
		fin.bigEndian = true;
		if ((fin.readInt32() != 0x89504E47) || (fin.readInt32() != 0x0D0A1A0A)) 
			throw "NOT a PNG file : " + fileName; // Wrong MagicNumber...
		var len = fin.readInt32();
		var chunkType = fin.readInt32();
		if ((len != 13) || ((chunkType != ('I'.code << 24) | ('H'.code << 16) | ('D'.code << 8) | 'R'.code)))
			throw "Wrong PNG file : " + fileName + ', len = ' + len + ", chunkType = " + chunkType;
		for (i in 0...9) // Skip Width, Heigth & BitDepth
			fin.readInt8();
		var colorType = fin.readInt8();
		fin.close();
		return colorType;
	}

	function convertPNGtoDDS(nMipMaps : Int = 0, bSilent : Bool = true) : String {
		var tmpStr = srcPath.toLowerCase();
		if (tmpStr.indexOf("gradients/") != -1)
			return null; // Do NOT convert gradients maps
		if ((tmpStr.indexOf("beheaded") != -1) && (tmpStr.indexOf("_n.") == -1))
			return null; // Do NOT convert 'indexed' beheaded (except normal maps)
		var sdkRoot = Sys.getEnv("NINTENDO_SDK_ROOT");
		if ((Sys.systemName() != "Windows") || (sdkRoot == null)) {
			if (bWarn) {
				trace("Invalid configuration (will not convert)");
				trace("\tsystemName = " + Sys.systemName);
				trace("\tsdkRoot = " + sdkRoot);
				bWarn = false;
			}
			return null;
		}
		var format;
		switch (getColorType(srcPath)) {
			case 4, 6:	format = "unorm_bc3";
			default:	format = "unorm_bc1";
		}
		var cmd = sdkRoot + "/Tools/Graphics/3dTools/3dTextureConverter.exe";
		var dstName = dstPath.split(".eef")[0] + ".dds";
		var params = [srcPath, "-o", dstName, "-f", format];
		params.push("-i " + nMipMaps);
		if (bSilent)
			params.push("--silent");
		var ret = Sys.command(cmd, params);
		if (ret != 0)
			throw cmd + " FAILED : " + srcPath + ", returnCode = " + ret;
		return dstName;
	}

	function convertDDStoEEF(ddsName : String) {
		var fin = sys.io.File.read(ddsName);
		var src = fin.readAll();
		fin.close();
		if (src.getInt32(0) != hxd.res.Image.MagicNumber.MN_DDS)
			throw "Wrong DDS file : " + ddsName;
		var rawSize : Int = src.length;
		var res = haxe.zip.Compress.run(src, compressLevel);
		var zipSize : Int = res.length;
		var fout = sys.io.File.write(dstPath);
		fout.writeInt32(hxd.res.Image.MagicNumber.MN_EEF);
		fout.writeInt32(zipSize);
		fout.writeInt32(rawSize);
		fout.write(res);
		fout.close();
	}

	override function convert() {
		var ddsName = convertPNGtoDDS();
		if (ddsName == null) // Keep the PNG untouched
			sys.io.File.copy(srcPath, dstPath);
		else { // Replace it by an 'EEF' file (and remove temp DDS file)
			convertDDStoEEF(ddsName);
			sys.FileSystem.deleteFile(ddsName);
		}
	}
}
