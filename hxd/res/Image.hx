package hxd.res;

@:enum abstract ImageFormat(Int) {

	var Jpg = 0;
	var Png = 1;
	var Gif = 2;
	var Tga = 3;
	//var Dds = 4;
	//var Raw32 = 5;

	/*
		Tells if we might not be able to directly decode the image without going through a loadBitmap async call.
		This for example occurs when we want to decode progressive JPG in JS.
	*/
	public var useAsyncDecode(get, never) : Bool;

	inline function get_useAsyncDecode() {
		#if hl
		return false;
		#else
		return this == Jpg.toInt();
		#end
	}

	inline function toInt() return this;

}

class Image extends Resource {

	/**
		Specify if we will automatically convert non-power-of-two textures to power-of-two.
	**/
	public static var ALLOW_NPOT = #if (flash && !flash11_8) false #else true #end;
	public static var DEFAULT_FILTER : h3d.mat.Data.Filter = Linear;

	/**
		Forces async decoding for images if available on the target platform.
	**/
	public static var DEFAULT_ASYNC = false;

	static var ENABLE_AUTO_WATCH = true;

	var tex : h3d.mat.Texture;
	var inf : { width : Int, height : Int, format : ImageFormat, bc : Int };

	public function getFormat() {
		getSize();
		return inf.format;
	}

	public function getSize() : { width : Int, height : Int } {
		if( inf != null )
			return inf;
		var f = new hxd.fs.FileInput(entry);
		var width = 0, height = 0, format, bc = 0;
		var head = try f.readUInt16() catch( e : haxe.io.Eof ) 0;

		#if debug
		if( head == 0 ) {
			do {
				Sys.sleep(0.01);
				head = try f.readUInt16() catch( e : haxe.io.Eof ) 0;
			} while( head == 0 );
		}
		#end
		switch( head ) {
		case 0xD8FF: // JPG
			format = Jpg;
			f.bigEndian = true;
			while( true ) {
				switch( f.readUInt16() ) {
				case 0xFFC2, 0xFFC1, 0xFFC0:
					var len = f.readUInt16();
					var prec = f.readByte();
					height = f.readUInt16();
					width = f.readUInt16();
					break;
				default:
					f.skip(f.readUInt16() - 2);
				}
			}
		case 0x5089: // PNG
			format = Png;
			f.bigEndian = true;
			f.skip(6); // header
			while( true ) {
				var dataLen = f.readInt32();
				if( f.readInt32() == ('I'.code << 24) | ('H'.code << 16) | ('D'.code << 8) | 'R'.code ) {
					width = f.readInt32();
					height = f.readInt32();
					break;
				}
				f.skip(dataLen + 4); // CRC
			}
		case 0x4947: // GIF
			format = Gif;
			f.readInt32(); // skip
			width = f.readUInt16();
			height = f.readUInt16();
/*
		case 0x4444: // DDS
			format = Dds;
			f.skip(10);
			height = f.readInt32();
			width = f.readInt32();
			f.skip(16*4);
			var fourCC = f.readInt32();
			switch( fourCC & 0xFFFFFF ) {
			case 0x545844: // DXT 
				var dxt = (fourCC >>> 24) - "0".code;
				bc = switch( dxt ) {
				case 1: 1;
				case 2,3: 2;
				case 4,5: 3;
				default: 0;
				}
			case 0x495441: // ATI 
				var v = (fourCC >>> 24) - "0".code;
				bc = switch( v ) {
				case 1: 4;
				case 2: 5;
				default: 0;
				}
			case _ if( fourCC == 0x30315844 ): // DX10 
				f.skip(40);
				var dxgi = f.readInt32(); // DXGI_FORMAT_xxxx value
				switch( dxgi ) {
				case 95: // BC6H_UF16
					bc = 6;
				case 98: // BC7_UNORM
					bc = 7;
				default:
					throw entry.path+" has unsupported DXGI format "+dxgi;
				}
			}

			if( bc == 0 )
				throw entry.path+" has unsupported 4CC "+String.fromCharCode(fourCC&0xFF)+String.fromCharCode((fourCC>>8)&0xFF)+String.fromCharCode((fourCC>>16)&0xFF)+String.fromCharCode(fourCC>>>24);
*/
		case _ if( entry.extension == "tga" ):
			format = Tga;
			f.skip(10);
			width = f.readUInt16();
			height = f.readUInt16();
/*
		case _ if( entry.extension == "raw" ):
			format = Raw32;
			var size = Std.int(Math.sqrt(entry.size>>2));
			if( entry.size != size * size * 4 ) throw "RAW format does not match 32 bit per components on "+size+"x"+size;
			width = height = size;
*/
		default:
			throw "Unsupported texture format " + entry.path;
		}
		f.close();
		inf = { width : width, height : height, format : format, bc : bc };
		return inf;
	}

	public function getPixels( ?fmt : PixelFormat, ?flipY : Bool ) {
		getSize();
		var pixels : hxd.Pixels;
		switch( inf.format ) {
		case Png:
			var bytes = entry.getBytes(); // using getTmpBytes cause bug in E2

			#if hl
			if( fmt == null ) fmt = BGRA;
			pixels = decodePNG(bytes, inf.width, inf.height, fmt, flipY);
			if( pixels == null ) throw "Failed to decode PNG " + entry.path;
			#else
			var png = new format.png.Reader(new haxe.io.BytesInput(bytes));
			png.checkCRC = false;
			pixels = Pixels.alloc(inf.width, inf.height, BGRA);
			#if( format >= "3.1.3" )
			var pdata = png.read();
			format.png.Tools.extract32(pdata, pixels.bytes, flipY);
			if( flipY ) pixels.flags.set(FlipY);
			#else
			format.png.Tools.extract32(png.read(), pixels.bytes);
			#end
			#end
		case Gif:
			var bytes = entry.getBytes();
			var gif = new format.gif.Reader(new haxe.io.BytesInput(bytes)).read();
			pixels = new Pixels(inf.width, inf.height, format.gif.Tools.extractFullBGRA(gif, 0), BGRA);
		case Jpg:
			var bytes = entry.getBytes();
			#if hl
			if( fmt == null ) fmt = BGRA;
			pixels = decodeJPG(bytes, inf.width, inf.height, fmt, flipY);
			if( pixels == null ) throw "Failed to decode JPG " + entry.path;
			#else
			var p = try NanoJpeg.decode(bytes) catch( e : Dynamic ) throw "Failed to decode JPG " + entry.path + " (" + e+")";
			pixels = new Pixels(p.width, p.height, p.pixels, BGRA);
			#end

		case Tga:
			var bytes = entry.getBytes();
			var r = new format.tga.Reader(new haxe.io.BytesInput(bytes)).read();
			if( r.header.imageType != UncompressedTrueColor || r.header.bitsPerPixel != 32 )
				throw "Not supported "+r.header.imageType+"/"+r.header.bitsPerPixel;
			var w = r.header.width;
			var h = r.header.height;
			pixels = hxd.Pixels.alloc(w, h, ARGB);
			var access : hxd.Pixels.PixelsARGB = pixels;
			var p = 0;
			for( y in 0...h )
				for( x in 0...w ) {
					var c = r.imageData[x + y * w];
					access.setPixel(x, y, c);
				}
			switch( r.header.imageOrigin ) {
			case BottomLeft: pixels.flags.set(FlipY);
			case TopLeft: // nothing
			default: throw "Not supported "+r.header.imageOrigin;
			}
/*
		case Dds:
			var bytes = entry.getBytes();
			pixels = new hxd.Pixels(inf.width, inf.height, bytes, S3TC(inf.bc), 128 + (inf.bc >= 6 ? 20 : 0));
		case Raw32:
			var bytes = entry.getBytes();
			pixels = new hxd.Pixels(inf.width, inf.height, bytes, R32F);
*/
		}
		if( fmt != null ) pixels.convert(fmt);
		if( flipY != null ) pixels.setFlip(flipY);
		return pixels;
	}

	#if hl
	static function decodeJPG( src : haxe.io.Bytes, width : Int, height : Int, fmt : hxd.PixelFormat, flipY : Bool ) {
		var ifmt : hl.Format.PixelFormat = switch( fmt ) {
		case RGBA: RGBA;
		case BGRA: BGRA;
		case ARGB: ARGB;
		default:
			fmt = BGRA;
			BGRA;
		};
		var dst = haxe.io.Bytes.alloc(width * height * 4);
		if( !hl.Format.decodeJPG(src.getData(), src.length, dst.getData(), width, height, width * 4, ifmt, (flipY?1:0)) )
			return null;
		var pix = new hxd.Pixels(width, height, dst, fmt);
		if( flipY ) pix.flags.set(FlipY);
		return pix;
	}

	static function decodePNG( src : haxe.io.Bytes, width : Int, height : Int, fmt : hxd.PixelFormat, flipY : Bool ) {
		var ifmt : hl.Format.PixelFormat = switch( fmt ) {
		case RGBA: RGBA;
		case BGRA: BGRA;
		case ARGB: ARGB;
		default:
			fmt = BGRA;
			BGRA;
		};
		var dst = haxe.io.Bytes.alloc(width * height * 4);
		if( !hl.Format.decodePNG(src.getData(), src.length, dst.getData(), width, height, width * 4, ifmt, (flipY?1:0)) )
			return null;
		var pix = new hxd.Pixels(width, height, dst, fmt);
		if( flipY ) pix.flags.set(FlipY);
		return pix;
	}
	#end

	public function toBitmap() : hxd.BitmapData {
		getSize();
		var bmp = new hxd.BitmapData(inf.width, inf.height);
		var pixels = getPixels();
		bmp.setPixels(pixels);
		pixels.dispose();
		return bmp;
	}

	//See hxd.res.Resource::watch method, it is safely secured there
	function watchCallb() {
		var w = inf.width, h = inf.height;
		inf = null;
		var s = getSize();
		if( w != s.width || h != s.height )
			tex.resize(w, h);
		tex.realloc = null;
		loadTexture();
		trace('image ${entry.path} reloaded');
	}

	function loadTexture() {
		if( !getFormat().useAsyncDecode && !DEFAULT_ASYNC ) {
			function load() {
				try {
					// immediately loading the PNG is faster than going through loadBitmap
					tex.alloc();
					var pixels = getPixels(tex.format);
					if( pixels.width != tex.width || pixels.height != tex.height )
						pixels.makeSquare();
					tex.uploadPixels(pixels);
					pixels.dispose();
					tex.realloc = loadTexture;
					if(ENABLE_AUTO_WATCH)
						watch(watchCallb);
				} catch(e:Dynamic) {
					//Image might be re-written at the moment and can't be parsed
					Sys.sleep(0.1);
					load();
					return;
				}
			}

			if( entry.isAvailable )
				load();
			else
				entry.load(load);
		} else {
			// use native decoding
			tex.flags.set(Loading);
			entry.loadBitmap(function(bmp) {
				var bmp = bmp.toBitmap();
				tex.alloc();

				if( bmp.width != tex.width || bmp.height != tex.height ) {
					var pixels = bmp.getPixels();
					pixels.makeSquare();
					tex.uploadPixels(pixels);
					pixels.dispose();
				} else
					tex.uploadBitmap(bmp);

				bmp.dispose();
				tex.realloc = loadTexture;
				tex.flags.unset(Loading);
				@:privateAccess if( tex.waitLoads != null ) {
					var arr = tex.waitLoads;
					tex.waitLoads = null;
					for( f in arr ) f();
				}

				if(ENABLE_AUTO_WATCH)
					watch(watchCallb);
			});
		}
	}

	public function toTexture() : h3d.mat.Texture {
		if( tex != null )
			return tex;
		getSize();
		var width = inf.width, height = inf.height;
		if( !ALLOW_NPOT ) {
			var tw = 1, th = 1;
			while( tw < width ) tw <<= 1;
			while( th < height ) th <<= 1;
			width = tw;
			height = th;
		}
		var format = h3d.mat.Texture.nativeFormat;
/*
		switch( inf.format ) {
		case Dds:
			format = S3TC(inf.bc);
		case Raw32:
			format = R32F;
		default:
		}
*/
		tex = new h3d.mat.Texture(width, height, [NoAlloc], format);
		if( DEFAULT_FILTER != Linear ) tex.filter = DEFAULT_FILTER;
		tex.setName(entry.path);
		loadTexture();
		return tex;
	}

	public function toTile() : h2d.Tile {
		var size = getSize();
		return h2d.Tile.fromTexture(toTexture()).sub(0, 0, size.width, size.height);
	}

}