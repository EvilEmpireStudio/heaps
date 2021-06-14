package hxd.res;

@:enum abstract MagicNumber(Int) to Int {
	var MN_DDS = 0x20534444;
	var MN_EEF_L = 0x5678;
	var MN_EEF_H = 0x1234;
	var MN_EEF = (MN_EEF_H << 16) | MN_EEF_L;
}

// From Dds.h :
@:enum abstract DDPF(Int) to Int {
	var DDPF_FOURCC	= 0x4;
	var DDPF_RGB	= 0x40;
}

// From Dds.h :
@:enum abstract D3DFMT(Int) to Int {
	var D3DFMT_R16F				= 111;
	var D3DFMT_G16R16F			= 112;
	var D3DFMT_A16B16G16R16F	= 113;
	var D3DFMT_R32F				= 114;
	var D3DFMT_G32R32F			= 115;
	var D3DFMT_A32B32G32R32F	= 116;

	var D3DFMT_DXT1 = 'D'.code | ('X'.code << 8) | ('T'.code << 16) | ('1'.code << 24);
	var D3DFMT_DXT3 = 'D'.code | ('X'.code << 8) | ('T'.code << 16) | ('3'.code << 24);
	var D3DFMT_DXT5 = 'D'.code | ('X'.code << 8) | ('T'.code << 16) | ('5'.code << 24);
	var D3DFMT_BC4U = 'B'.code | ('C'.code << 8) | ('4'.code << 16) | ('U'.code << 24);
	var D3DFMT_BC5U = 'B'.code | ('C'.code << 8) | ('5'.code << 16) | ('U'.code << 24);
	var D3DFMT_ATI1 = 'A'.code | ('T'.code << 8) | ('I'.code << 16) | ('1'.code << 24);
	var D3DFMT_ATI2 = 'A'.code | ('T'.code << 8) | ('I'.code << 16) | ('2'.code << 24);

	var D3DFMT_DX10 = 'D'.code | ('X'.code << 8) | ('1'.code << 16) | ('0'.code << 24);
}

// From dxgiformat.h :
@:enum abstract DXGI_FORMAT(Int) to Int {
	var DXGI_FORMAT_R32G32B32A32_FLOAT	= 2;
	var DXGI_FORMAT_R32G32B32_FLOAT		= 6;
	var DXGI_FORMAT_R16G16B16A16_FLOAT	= 10;
	var DXGI_FORMAT_R32G32_FLOAT		= 16;
	var DXGI_FORMAT_R10G10B10A2_UNORM	= 24;
	var DXGI_FORMAT_R11G11B10_FLOAT		= 26;
	var DXGI_FORMAT_R8G8B8A8_UNORM_SRGB	= 29;
	var DXGI_FORMAT_R16G16_FLOAT		= 34;
	var DXGI_FORMAT_R32_FLOAT			= 41;
	var DXGI_FORMAT_R16_FLOAT			= 54;
	var DXGI_FORMAT_BC1_UNORM			= 71;
	var DXGI_FORMAT_BC2_UNORM			= 74;
	var DXGI_FORMAT_BC3_UNORM			= 77;
	var DXGI_FORMAT_BC4_UNORM			= 80;
	var DXGI_FORMAT_BC5_UNORM			= 83;
	var DXGI_FORMAT_BC6H_UF16			= 95;
	var DXGI_FORMAT_BC7_UNORM			= 98;
}

@:enum abstract PixelFormatExt(Int) to Int {
	var PF_UNKNOWN = 0x0;

	var PF_R8	= 0x1;
	var PF_RG8	= 0x2;
	var PF_RGB8	= 0x3;
	var PF_ARGB	= 0x4;
	var PF_BGRA	= 0x5;
	var PF_RGBA	= 0x6;

	var PF_R16F		= 0x11;
	var PF_RG16F	= 0x12;
	var PF_RGBA16F	= 0x13;

	var PF_R32F		= 0x21;
	var PF_RG32F	= 0x22;
	var PF_RGB32F	= 0x23;
	var PF_RGBA32F	= 0x24;

	var PF_RGB10A2		= 0x31;
	var PF_RG11B10UF	= 0x32;
	var PF_SRGB_ALPHA	= 0x33;

	var PF_BC1	= 0x41;
	var PF_BC2	= 0x42;
	var PF_BC3	= 0x43;
	var PF_BC4	= 0x44;
	var PF_BC5	= 0x45;
	var PF_BC6H	= 0x46;
	var PF_BC7	= 0x47;

	var PF_TBD = 0x100;
}

class TextureEEF {
	var width : Int;
	var height : Int;
	var nmips : Int;
	var pixelFormat : PixelFormatExt;
	var data : haxe.io.Bytes;

	var dds : { data : haxe.io.Bytes, curPos : Int };

	public function new() {
		pixelFormat = PF_UNKNOWN;
		data = null;
	}

	public function isValid() : Bool {
		return ((pixelFormat != PF_UNKNOWN) && (data != null));
	}

	function readI32() : Int {
		if (cast(dds.curPos + 4, UInt) >= cast(dds.data.length, UInt))
			return -1;
		var v = dds.data.getInt32(dds.curPos);
		dds.curPos += 4;
		return v;
	}

	function readDDS_PixelFormat() : Void {
		if (readI32() == 32) {
			var flagsPF = readI32();
			var fourCC = readI32();
			var bpp = readI32();
			if ((flagsPF & DDPF_RGB) != 0) {
				var rMask = readI32();
				var gMask = readI32();
				var bMask = readI32();
				var aMask = readI32();
				switch (bpp) {
					case 8:		pixelFormat = PF_R8;
					case 16:	pixelFormat = PF_RG8;
					case 24:	pixelFormat = PF_RGB8;
					case 32:
						switch ([rMask, gMask, bMask, aMask]) {
							case [0xFF00, 0xFF0000, 0xFF000000, 0xFF]:	pixelFormat = PF_ARGB;
							case [0xFF0000, 0xFF00, 0xFF, 0xFF000000]:	pixelFormat = PF_BGRA;
							case [0xFF, 0xFF00, 0xFF0000, 0xFF000000]:	pixelFormat = PF_RGBA;
							default:
								pixelFormat = PF_UNKNOWN;
								throw "Unsupported RGB32 DDS (yet) : " + [rMask, gMask, bMask, aMask];
						}
					default:
						pixelFormat = PF_UNKNOWN;
						throw "Unsupported RGB DDS bpp : " + bpp;
				}
			}
			else if ((flagsPF & DDPF_FOURCC) != 0) {
				dds.curPos += 4 * 4; // [R,G,B,A]Mask
				switch (fourCC) {
					case D3DFMT_R16F:				pixelFormat = PF_R16F;
					case D3DFMT_G16R16F:			pixelFormat = PF_RG16F;
					case D3DFMT_A16B16G16R16F:		pixelFormat = PF_RGBA16F;
					case D3DFMT_R32F:				pixelFormat = PF_R32F;
					case D3DFMT_G32R32F:			pixelFormat = PF_RG32F;
					case D3DFMT_A32B32G32R32F:		pixelFormat = PF_RGBA32F;
					case D3DFMT_DXT1:				pixelFormat = PF_BC1;
					case D3DFMT_DXT3:				pixelFormat = PF_BC2;
					case D3DFMT_DXT5:				pixelFormat = PF_BC3;
					case D3DFMT_BC4U, D3DFMT_ATI1:	pixelFormat = PF_BC4;
					case D3DFMT_BC5U, D3DFMT_ATI2:	pixelFormat = PF_BC5;
					case D3DFMT_DX10:				pixelFormat = PF_TBD;
					default:
						pixelFormat = PF_UNKNOWN;
						throw "Unsupported FourCC DDS : " + StringTools.hex(fourCC);
				}
			}
		}
	}

	function readDDS_Header() : Void {
		var type = readI32();
		if ((type == MN_DDS) && (readI32() == 124)) {
			dds.curPos += 4; // skip Flags
			height = readI32();
			width = readI32();
			dds.curPos += 8; // PitchOrLinearSize & Depth
			nmips = readI32();
			dds.curPos += 11 * 4; // Reserved
			readDDS_PixelFormat();
			dds.curPos += 5 * 4; // Caps[1,2,3,4] & Reserved2
			if (pixelFormat == PF_TBD) {
				var pf = readI32();
				switch (pf) {
					case DXGI_FORMAT_R32G32B32A32_FLOAT:	pixelFormat = PF_RGBA32F;
					case DXGI_FORMAT_R32G32B32_FLOAT:		pixelFormat = PF_RGB32F;
					case DXGI_FORMAT_R16G16B16A16_FLOAT:	pixelFormat = PF_RGBA16F;
					case DXGI_FORMAT_R32G32_FLOAT:			pixelFormat = PF_RG32F;
					case DXGI_FORMAT_R10G10B10A2_UNORM:		pixelFormat = PF_RGB10A2;
					case DXGI_FORMAT_R11G11B10_FLOAT:		pixelFormat = PF_RG11B10UF;
					case DXGI_FORMAT_R8G8B8A8_UNORM_SRGB:	pixelFormat = PF_SRGB_ALPHA;
					case DXGI_FORMAT_R16G16_FLOAT:			pixelFormat = PF_RG16F;
					case DXGI_FORMAT_R32_FLOAT:				pixelFormat = PF_R32F;
					case DXGI_FORMAT_R16_FLOAT:				pixelFormat = PF_R16F;
					case DXGI_FORMAT_BC1_UNORM:				pixelFormat = PF_BC1;
					case DXGI_FORMAT_BC2_UNORM:				pixelFormat = PF_BC2;
					case DXGI_FORMAT_BC3_UNORM:				pixelFormat = PF_BC3;
					case DXGI_FORMAT_BC4_UNORM:				pixelFormat = PF_BC4;
					case DXGI_FORMAT_BC5_UNORM:				pixelFormat = PF_BC5;
					case DXGI_FORMAT_BC6H_UF16:				pixelFormat = PF_BC6H;
					case DXGI_FORMAT_BC7_UNORM:				pixelFormat = PF_BC7;
					default:
						pixelFormat = PF_UNKNOWN;
						throw "Unsupported DX10 DDS PixelFormat : " + pf;
				}
				dds.curPos += 4 * 4; // resDim, miscFlag, arraySize & miscFlags2
			}
		}
	}

	public function parse(src : haxe.io.Bytes) : Bool {
		var zip = new haxe.zip.Uncompress();
		var dstSize = src.getInt32(0);
		var dst = haxe.io.Bytes.alloc(dstSize);
		zip.execute(src, 4, dst, 0);
		dds = { data: dst, curPos: 0 };
		if (dds.data != null) {
			readDDS_Header();
			if (pixelFormat != PF_UNKNOWN) {
				data = dds.data.sub(dds.curPos, dds.data.length - dds.curPos);
				dds.data = null; // Not used anymore
			}
		}
		return isValid();
	}

	// As a single file
	public function read(fileName : String) : Bool {
		var file = sys.io.File.read(fileName);
		var type = file.readInt32();
		if (type != MN_EEF)
			throw "Unknown file type : " + StringTools.hex(type);
		var dataSize = file.readInt32();
		var src = haxe.io.Bytes.alloc(dataSize);
		file.readFullBytes(src, 0, dataSize);
		file.close();
		return parse(src);
	}

	public function toPixelFormat() : hxd.PixelFormat {
		switch (pixelFormat) {
			case PF_R8:			return hxd.PixelFormat.R8;
			case PF_RG8:		return hxd.PixelFormat.RG8;
			case PF_RGB8:		return hxd.PixelFormat.RGB8;
			case PF_ARGB:		return hxd.PixelFormat.ARGB;
			case PF_BGRA:		return hxd.PixelFormat.BGRA;
			case PF_RGBA:		return hxd.PixelFormat.RGBA;
			case PF_R16F:		return hxd.PixelFormat.R16F;
			case PF_RG16F:		return hxd.PixelFormat.RG16F;
			case PF_RGBA16F:	return hxd.PixelFormat.RGBA16F;
			case PF_R32F:		return hxd.PixelFormat.R32F;
			case PF_RG32F:		return hxd.PixelFormat.RG32F;
			case PF_RGB32F:		return hxd.PixelFormat.RGB32F;
			case PF_RGBA32F:	return hxd.PixelFormat.RGBA32F;
			case PF_RGB10A2:	return hxd.PixelFormat.RGB10A2;
			case PF_RG11B10UF:	return hxd.PixelFormat.RG11B10UF;
			case PF_SRGB_ALPHA:	return hxd.PixelFormat.SRGB_ALPHA;
			case PF_BC1:		return hxd.PixelFormat.BC1;
			case PF_BC2:		return hxd.PixelFormat.BC2;
			case PF_BC3:		return hxd.PixelFormat.BC3;
			case PF_BC4:		return hxd.PixelFormat.BC4;
			case PF_BC5:		return hxd.PixelFormat.BC5;
			case PF_BC6H:		return hxd.PixelFormat.BC6H;
			case PF_BC7:		return hxd.PixelFormat.BC7;
			default:
				throw "toPixelFormat FATAL ERROR";
		}
	}
}

@:enum abstract ImageFormat(Int) {

	var Jpg = 0;
	var Png = 1;
	var Gif = 2;
	var Tga = 3;
	var Eef = 1000;

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

	var texEEF : TextureEEF = null;
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
		case MN_EEF_L: // EEF
			if (f.readUInt16() != MN_EEF_H)
				throw "Unsupported texture format " + entry.path;
			var dataSize = f.readInt32();
			var src = haxe.io.Bytes.alloc(dataSize);
			f.readFullBytes(src, 0, dataSize);
			texEEF = new TextureEEF();
			if (!texEEF.parse(src))
				throw "Failed to decode EEF Texture" + entry.path;
			@:privateAccess {
				format = Eef;
				width = texEEF.width;
				height = texEEF.height;
			}	
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
		case _ if( entry.extension == "tga" ):
			format = Tga;
			f.skip(10);
			width = f.readUInt16();
			height = f.readUInt16();

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
		case Eef:
			var hxdFormat = texEEF.toPixelFormat();
			pixels = new Pixels(inf.width, inf.height, @:privateAccess texEEF.data, hxdFormat);
			if ((hxdFormat != BGRA) && (hxdFormat != ARGB) && (hxdFormat != RGBA))
				return pixels;
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
			var nTry : Int = 0;
			function load() {
				try {
					// immediately loading the PNG is faster than going through loadBitmap
					if (texEEF != null)
						@:privateAccess tex.format = texEEF.toPixelFormat();
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
					if (++nTry == 50) {
						// If we have a real pb (like an invalid img / fmt),
						throw e;	// let's throw after a while
					}
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
