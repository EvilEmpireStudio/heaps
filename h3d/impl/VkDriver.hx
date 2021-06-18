package h3d.impl;

import h3d.mat.Pass;
import h3d.mat.Stencil;
import h3d.impl.Driver;
import vk.Vk;

class VkDriver extends h3d.impl.Driver {

	var frame : Int = 0;
	var defaultDepth : h3d.mat.DepthBuffer = null;
	var bufferWidth : Int = 0;
	var bufferHeight : Int = 0;
	var curShaderInfo : Int = -1;
	var shaderInfos = new Map<Int, Int>();	// shader.id -> (fs_TexNot2D_Count 4bits | fs_Tex2D_Count 4bits | vkShaderID 24bits)

	public function new(antiAlias = 0) {
		if (!Vk.init("Dead Cells", 1, "heaps", 1))
			throw "Vulkan init FAILED";
		#if hlsdl
		@:privateAccess if (!Vk.useSdl(hxd.Window.getInstance().window.win))
			throw "Fatal error : Can't present on the SDL surface";
			trace("Vulkan init (using a SDL window) SUCCESS");
		#else
		trace("Vulkan init SUCCESS");
		#end
	}

	override public function init(onCreate : Bool -> Void, forceSoftware = false) {
		haxe.Timer.delay(onCreate.bind(false), 1);
	}

	override public function isDisposed() {
		return Vk.isDeviceLost();
	}

	override public function getDriverName(details : Bool) {
		return @:privateAccess String.fromUTF8(Vk.getDeviceInfos());
	}

	override public function allocVertexes(m : ManagedBuffer) : VertexBuffer {
		var b = Vk.createVertexBuffer(m.size * m.stride << 2);
		if (b == null) return null;
		return { b : b, stride : m.stride };
	}

	override public function allocIndexes(count : Int, is32 : Bool) : IndexBuffer {
		var b = Vk.createIndexBuffer(count, is32);
		if (b == null) return null;
		return { b : b, bits : (is32 ? 2 : 1) };
	}

	override public function allocTexture(t : h3d.mat.Texture) : Texture {
		var l = t.flags.has(IsArray) ? t.layerCount : 1;
		var tt = Vk.createTexture(t.format.getIndex(), t.width, t.height, t.flags.has(MipMapped), l, t.flags.has(Cube));
		if (tt == null) return null;
		t.lastFrame = frame;
		t.flags.unset(WasCleared);
		#if debug Vk.setImageDebugName(tt, @:privateAccess ((t.name != null) ? t.name : ("id="+t.id)).toUtf8()); #end 
		return { t : tt };
	}

	override public function disposeVertexes(v : VertexBuffer) {
		Vk.deleteVertexBuffer(v.b);
		v.b = null;
	}

	override public function disposeIndexes(i : IndexBuffer) {
		Vk.deleteIndexBuffer(i.b);
		i.b = null;
	}

	override public function disposeTexture(t : h3d.mat.Texture) {
		if (t.t != null) {
			Vk.deleteTexture(t.t.t);
			t.t.t = null;
			t.t = null;
		}
	}

	override public function hasFeature(f: Feature) : Bool {
		return true;
	}

	override public function uploadVertexBuffer(v : VertexBuffer, startVertex : Int, vertexCount : Int, buf : hxd.FloatBuffer, bufPos : Int) {
		Vk.updateBuffer(v.b, startVertex * v.stride << 2, vertexCount * v.stride << 2, hl.Bytes.getArray(buf.getNative()).offset(bufPos << 2));
	}

	override public function uploadVertexBytes(v:VertexBuffer, startVertex:Int, vertexCount:Int, buf:haxe.io.Bytes, bufPos:Int) {
		Vk.updateBuffer(v.b, startVertex * v.stride << 2, vertexCount * v.stride << 2, @:privateAccess buf.b.offset(bufPos << 2));
	}

	override public function uploadIndexBuffer(i:IndexBuffer, startIndice:Int, indiceCount:Int, buf:hxd.IndexBuffer, bufPos:Int) {
		Vk.updateBuffer(i.b, startIndice << i.bits, indiceCount << i.bits, hl.Bytes.getArray(buf.getNative()).offset(bufPos << i.bits));
	}

	override public function uploadIndexBytes(i:IndexBuffer, startIndice:Int, indiceCount:Int, buf:haxe.io.Bytes, bufPos:Int) {
		Vk.updateBuffer(i.b, startIndice << i.bits, indiceCount << i.bits, @:privateAccess buf.b.offset(bufPos << i.bits));
	}

	override public function clear(?color : h3d.Vector, ?depth : Float, ?stencil : Int) {
		var mask : Int = 0, s : Int = 0, d : Float = 0;
		var r : Float = 0, g : Float = 0, b : Float = 0, a : Float = 0;
		if (color != null) {
			mask |= 0x1;
			r = color.r;  g = color.g;  b = color.b;  a = color.a;
		}
		if (depth != null) {
			mask |= 0x2;
			d = depth;
		}
		if (stencil != null) {
			mask |= 0x4;
			s = stencil;
		}
		Vk.clear(mask, r, g, b, a, d, s);
	}

	override public function isSupportedFormat(fmt : h3d.mat.Data.TextureFormat) : Bool {
		// Be careful, in vulkan a "supported" format is all about the usage (sampling, storage, blit, etc.)
		// For now, this function will return 'true' if the format can be used for a sampled image (typical use of a texture)
		return Vk.isValidTextureFormat(fmt.getIndex());
	}

	override public function allocDepthBuffer(b : h3d.mat.DepthBuffer) : DepthBuffer {
		if (b.format == null)
			@:privateAccess b.format = Depth24Stencil8;
		var r = Vk.createDepthBuffer(b.format.getIndex(), b.width, b.height);
		if (r == null) return null;
		return { r : r };
	}

	override public function disposeDepthBuffer(b : h3d.mat.DepthBuffer) {
		@:privateAccess if ((b.b != null) && (b.b.r != null)) {
			Vk.deleteDepthBuffer(b.b.r);
			b.b = null;
		}
	}

	override function getDefaultDepthBuffer() : h3d.mat.DepthBuffer {
		if (defaultDepth != null)
			return defaultDepth;
		defaultDepth = new h3d.mat.DepthBuffer(0, 0);
		@:privateAccess {
			defaultDepth.width = bufferWidth;
			defaultDepth.height = bufferHeight;
			defaultDepth.b = allocDepthBuffer(defaultDepth);
		}
		return defaultDepth;
	}

	inline function toCubeSide(id : Int) : Int { return id; }
	override public function uploadTexturePixels(t : h3d.mat.Texture, pixels : hxd.Pixels, mipLevel : Int, side : Int) {
		if ((t.t != null) && (t.t.t != null)) {
			pixels.convert(t.format);
			pixels.setFlip(false);
			var layer = t.flags.has(Cube) ? toCubeSide(side) : side;	
			Vk.updateTexture(t.t.t, mipLevel, layer, (pixels.bytes:hl.Bytes).offset(pixels.offset));
		}
	}

	override public function uploadTextureBitmap(t : h3d.mat.Texture, bmp : hxd.BitmapData, mipLevel : Int, side : Int) {
		var pixels = bmp.getPixels();
		uploadTexturePixels(t, pixels, mipLevel, side);
		pixels.dispose();
	}

	override public function allocQuery(queryKind : QueryKind) : Query {
		return { q : Vk.createQuery(queryKind.getIndex()) };
	}

	override public function deleteQuery(q : Query) {
		if (q.q != null) {
			Vk.deleteQuery(q.q);
			q.q = null;
		}
	}

	override public function beginQuery(q : Query) {
		Vk.beginQuery(q.q);
	}

	override public function endQuery(q : Query) {
		Vk.endQuery(q.q);
	}

	override public function queryResultAvailable(q : Query) {
		return Vk.queryResultAvailable(q.q);
	}

	override public function queryResult(q : Query) {
		return Vk.queryResult(q.q);
	}

	override public function setRenderZone(x : Int, y : Int, width : Int, height : Int) {
		if ((x == 0) && (y == 0) && (width < 0) && (height < 0))
			Vk.setScissor(-1, -1, -1, -1);
		else {
			if (x < 0) { width += x;   x = 0; }
			if (y < 0) { height += y;  y = 0; }
			if  (width < 0)  width = 0;
			if (height < 0) height = 0;
			Vk.setScissor(x, y, width, height);	
		}
	}

	override public function draw(ibuf : IndexBuffer, startIndex : Int, ntriangles : Int) {
		Vk.bindIndexBuffer(ibuf.b);
		Vk.drawIndexed(ntriangles * 3, startIndex);
	}

	override public function getNativeShaderCode(shader : hxsl.RuntimeShader) {
		var glout = new hxsl.GlslOut();
		var glsl = glout.run(shader.vertex.data, 1);
		var result = "\n// vertex glsl:\n" + glsl + "// vertex SPIR-V:\n" + Vk.getNativeShaderCode(true, glsl);
		glsl = glout.run(shader.fragment.data, -1);
		return result + "\n// fragment glsl:\n" + glsl + "// fragment SPIR-V:\n" + Vk.getNativeShaderCode(false, glsl);
	}

	override public function selectShader(shader : hxsl.RuntimeShader) : Bool {
		var vk_id : Int, mask = shaderInfos.get(shader.id);
		if (mask != null)
			vk_id = mask & 0xFFFFFF;
		else
		{	// A new one, compile it :
			var glout = new hxsl.GlslOut();
			glout.setVulkanUBSize(Vk.getUniformBufferSize() >> 4); // >> 4 : BytesToVec4Count
			var vs = glout.run(shader.vertex.data, 1);
			var vf = glout.getVulkanVertexFormat();
			var fs = glout.run(shader.fragment.data, -1);
			var UBSizes = (shader.fragment.paramsSize << 24) | (shader.fragment.globalsSize << 16) 
						| (shader.vertex.paramsSize << 8) | shader.vertex.globalsSize ;
			vk_id = Vk.compileShader(vs, vf, fs, UBSizes);
			if (vk_id == -1)
				throw "Fatal error : Can't build shader " + shader.id;
			shader.vertex.code = vs;
			shader.fragment.code = fs;
			// Check sampled textures type :
			var tt = shader.fragment.textures;
			var count = 0;
			while (tt != null) {
				if (tt.type != TSampler2D)
					throw "GlslOut.hx[Vulkan] need an update to handle multiple sampler types";
				count++;
				tt = tt.next;
			}
			mask = (count << 24) | vk_id;
			shaderInfos.set(shader.id, mask);
		}
		var ret = Vk.setShader(vk_id);
		if (ret < 0)
			throw "Fatal error : Unknown shader : shader.id=" + shader.id + " (vk_id=" + vk_id + ")";
		curShaderInfo = mask;
		return (ret > 0); // If ret==0, this shader-program was already set
	}

	override public function selectMaterial(pass : h3d.mat.Pass) {
		@:privateAccess var bits = pass.bits;
		var b0 : Int, b1 : Int, b2 : Int;

		// b0 == 29 bits :
		b0 = Pass.getWireframe(bits); // 1 bit
		b0 <<= 2;	b0 |= (b0 == 0) ? Pass.getCulling(bits) : 0;
		b0 <<= 4;	b0 |= Pass.getBlendSrc(bits);
		b0 <<= 4;	b0 |= Pass.getBlendDst(bits);
		b0 <<= 4;	b0 |= Pass.getBlendAlphaSrc(bits);
		b0 <<= 4;	b0 |= Pass.getBlendAlphaDst(bits);
		b0 <<= 3;	b0 |= Pass.getBlendOp(bits);
		b0 <<= 3;	b0 |= Pass.getBlendAlphaOp(bits);
		b0 <<= 4;	b0 |= pass.colorMask;

		// b1 == 23 bits & b2 == 30 bits :
		b1 = Pass.getDepthWrite(bits); // 1 bit
		b1 <<= 3;	b1 |= Pass.getDepthTest(bits);
		if (pass.stencil != null) {
			@:privateAccess var stencilOpBits = pass.stencil.opBits;
			@:privateAccess var stencilMaskBits = pass.stencil.maskBits;

			b1 <<= 1;	b1 |= 1; // UseStencil
			b1 <<= 3;	b1 |= Stencil.getFrontSTfail(stencilOpBits);
			b1 <<= 3;	b1 |= Stencil.getFrontDPfail(stencilOpBits);
			b1 <<= 3;	b1 |= Stencil.getFrontPass(stencilOpBits);
			b1 <<= 3;	b1 |= Stencil.getBackSTfail(stencilOpBits);
			b1 <<= 3;	b1 |= Stencil.getBackDPfail(stencilOpBits);
			b1 <<= 3;	b1 |= Stencil.getBackPass(stencilOpBits);

			b2 = Stencil.getFrontTest(stencilOpBits); // 3 bits
			b2 <<= 3;	b2 |= Stencil.getBackTest(stencilOpBits);
			b2 <<= 8;	b2 |= Stencil.getReference(stencilMaskBits);
			b2 <<= 8;	b2 |= Stencil.getReadMask(stencilMaskBits);
			b2 <<= 8;	b2 |= Stencil.getWriteMask(stencilMaskBits);
		}
		else {
			b1 <<= 19;
			b2 = 0;
		}

		Vk.setPassInfos(b0, b1, b2);
	}

	public function updateDescriptors(buf : h3d.shader.Buffers.ShaderBuffers, which : h3d.shader.Buffers.BufferKind, shaderType : Int) {
		switch(which) {
		case Globals:
			if (buf.globals != null)
				Vk.fillUniformBuffer(shaderType, 0, hl.Bytes.getArray(buf.globals.toData()), buf.globals.length << 2);
		case Params:
			if (buf.params != null)
				Vk.fillUniformBuffer(shaderType, 1, hl.Bytes.getArray(buf.params.toData()), buf.params.length << 2);
		case Textures:
			var tex2DCount = (curShaderInfo >>> 24) & 0xF;
			var texCount = tex2DCount + (curShaderInfo >>> 28);
			for (i in 0...texCount) {
				var t = buf.tex[i];
				if ((t == null) || t.isDisposed()) {
					if (i < tex2DCount) {
						var color = h3d.mat.Defaults.loadingTextureColor;
						t = h3d.mat.Texture.fromColor(color, (color >>> 24) / 255);
					}
					else t = h3d.mat.Texture.defaultCubeTexture();
				}
				if ((t.t == null) && (t.realloc != null)) {
					t.alloc();
					t.realloc();
				}
				t.lastFrame = frame;
				var samplerID = (t.wrap.getIndex() << 2) | (((t.mipMap == Linear) ? 1 : 0) << 1) | t.filter.getIndex();
				Vk.addSampledTexture(i, t.t.t, samplerID);
			}
			Vk.updateTexDescriptor(texCount);
		case Buffers:
			if (buf.buffers != null)
				throw "updateDescriptors[Vulkan] does NOT handle 'case Buffers' (if needed, update GlslOut.hx & vkPipelineLayout)";
		}
	}

	override public function uploadShaderBuffers(buffers : h3d.shader.Buffers, which : h3d.shader.Buffers.BufferKind) {
		if (which != Textures)
			updateDescriptors(buffers.vertex, which, 0);
		updateDescriptors(buffers.fragment, which, 1);
	}

	override public function selectBuffer(buffer : Buffer) {
		var vbuf = @:privateAccess buffer.buffer.vbuf;
		Vk.bindVertexBuffer(0, vbuf.b);
	}

	override public function begin(frame : Int) {
		this.frame = frame;
		Vk.begin(frame);
	}

	override public function end() {
		Vk.end();
	}

	override public function present() {
		Vk.present(true);
	}

	override public function resize(width : Int, height : Int) {
		bufferWidth = width;
		bufferHeight = height;
		@:privateAccess if (defaultDepth != null) {
			disposeDepthBuffer(defaultDepth);
			defaultDepth.width = this.bufferWidth;
			defaultDepth.height = this.bufferHeight;
			defaultDepth.b = allocDepthBuffer(defaultDepth);
		}
		Vk.resize(width, height);
		setRenderTarget(null);
	}

	override public function captureRenderBuffer(pixels : hxd.Pixels) {
		Vk.capture(pixels.bytes.getData(), null, 0, 0, false);
	}

	override public function capturePixels(tex : h3d.mat.Texture, layer : Int, mipLevel : Int) : hxd.Pixels {
		var pixels = hxd.Pixels.alloc(tex.width >> mipLevel, tex.height >> mipLevel, tex.format);
		if ((tex.t != null) && (tex.t.t != null))
			Vk.capture(pixels.bytes.getData(), tex.t.t, mipLevel, layer, false);
		else
			throw "Trying to capture pixels from a null texture";
		return pixels;
	}

	override public function setRenderTarget(tex : Null<h3d.mat.Texture>, layer = 0, mipLevel = 0) {
		if ((layer > 0) || (mipLevel > 0))
			throw "setRenderTarget[Vulkan] does NOT handle layer!=0 or mipLevel!=0 yet";
		var bAnyChg : Int;
		if (tex == null) {
			bAnyChg = Vk.setRenderTarget(0, null);
			bAnyChg|= Vk.setDepthBuffer(@:privateAccess getDefaultDepthBuffer().b.r);
		}
		else {
			if (tex.t == null)
				tex.alloc();
			if (tex.flags.has(MipMapped) && !tex.flags.has(WasCleared))
				generateMipMaps(tex);
			tex.flags.set(WasCleared);
			tex.lastFrame = frame;
			bAnyChg = Vk.setRenderTarget(0, tex.t.t);
			bAnyChg|= Vk.setDepthBuffer((tex.depthBuffer != null) ? @:privateAccess tex.depthBuffer.b.r : null);
		}
		Vk.flushRenderTargets(1, bAnyChg);
	}

	override public function setRenderTargets(textures : Array<h3d.mat.Texture>) {
		if (textures.length == 0)
			setRenderTarget(null);
		else {
			var bAnyChg : Int = 0;
			for (i in 0...textures.length) {
				var tex = textures[i];
				if (tex.t == null)
					tex.alloc();
				tex.flags.set(WasCleared);
				tex.lastFrame = frame;
				bAnyChg |= Vk.setRenderTarget(i, tex.t.t);
			}
			bAnyChg |= Vk.setDepthBuffer((textures[0].depthBuffer != null) ? @:privateAccess textures[0].depthBuffer.b.r : null);
			Vk.flushRenderTargets(textures.length, bAnyChg);
		}
	}

	override public function allocInstanceBuffer(b : h3d.impl.InstanceBuffer, bytes : haxe.io.Bytes) {
		var size = b.commandCount * 20;
		if ((b.data = Vk.createIndirectBuffer(size)) != null)
			Vk.updateBuffer(b.data, 0, size, bytes);
	}

	override public function disposeInstanceBuffer(b : h3d.impl.InstanceBuffer) {
		Vk.deleteIndirectBuffer(b.data);
	}

	override public function drawInstanced(ibuf : IndexBuffer, commands : h3d.impl.InstanceBuffer ) {
		Vk.bindIndexBuffer(ibuf.b);
		Vk.drawIndexedIndirect(commands.data, commands.commandCount, commands.commandCount * 20);
	}

	override public function setRenderFlag(r : RenderFlag, value : Int) {
		#if debug trace("setRenderFlags : " + r + " = " + value); #end
	}

	override public function generateMipMaps(texture : h3d.mat.Texture) {
		if ((texture.t != null) && (texture.t.t != null))
			Vk.generateMipMaps(texture.t.t);
	}

	override public function selectMultiBuffers(buffers : Buffer.BufferOffset) {
		var b = buffers;
		var i = 0;
		while (b != null) {
			Vk.bindVertexBuffer(i++, @:privateAccess b.buffer.buffer.vbuf.b);
			b = b.next;
		}
	}
}
