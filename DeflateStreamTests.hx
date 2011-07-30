package;

import DeflateStream;
import flash.Memory;
import flash.system.ApplicationDomain;
import flash.utils.ByteArray;


class DeflateStreamTests
{
	public static function run()
	{
		testBufferResize();
		testEmptyHuffmanTree();
		testSimpleHuffmanTree();
		testSimpleCompression();
		testSimpleZlibCompression();
		testUncompressedCompression();
		testManyByteCompression();
		testIntegerOverflow();
		testBufferOverflow();
	}
	
	
	private static function testEmptyHuffmanTree()
	{
		// Arrange
		var weights = new Array<UInt>();
		
		// Act
		var tree = HuffmanTree.fromWeightedAlphabet(weights, 15);
		
		// Assert
		assert(tree.codes.length == 0);
	}
	
	
	private static function testSimpleHuffmanTree()
	{
		// Arrange
		var weights = [ 2, 3, 1, 1 ];
		
		// Act
		var tree = HuffmanTree.fromWeightedAlphabet(weights, 15);
		
		// Assert
		assert(tree.codes.length == 4);
		assert((tree.codes[0] >>> 16) == 1);		// Reversed code
		assert((tree.codes[0] & 0xFFFF) == 2);		// Length
		assert((tree.codes[1] >>> 16) == 0);
		assert((tree.codes[1] & 0xFFFF) == 1);
		assert(((tree.codes[2] >>> 16) & 0xFFFB) == 3);
		assert((tree.codes[2] & 0xFFFF) == 3);
		assert(((tree.codes[3] >>> 16) & 0xFFFB) == 3);
		assert((tree.codes[3] & 0xFFFF) == 3);
	}
	
	
	private static function testSimpleCompression()
	{
		// Arrange
		var bytes = new ByteArray();
		bytes.writeByte(1);
		bytes.writeByte(2);
		bytes.writeByte(3);
		
		bytes.position = 0;
		
		var stream = new DeflateStream(FAST);
		
		// Act
		stream.writeBlock(bytes, true);
		var result = stream.finalize();
		result.inflate();
		
		// Assert
		assert(result.readByte() & 0xFF == 1);
		assert(result.readByte() & 0xFF == 2);
		assert(result.readByte() & 0xFF == 3);
		assert(result.bytesAvailable == 0);
	}
	
	
	private static function testSimpleZlibCompression()
	{
		// Arrange
		var bytes = new ByteArray();
		bytes.writeByte(1);
		bytes.writeByte(2);
		bytes.writeByte(3);
		
		bytes.position = 0;
		
		var stream = new DeflateStream(FAST, true);
		
		// Act
		stream.writeBlock(bytes, true);
		var result = stream.finalize();
		result.uncompress();
		
		// Assert
		assert(result.readByte() & 0xFF == 1);
		assert(result.readByte() & 0xFF == 2);
		assert(result.readByte() & 0xFF == 3);
		assert(result.bytesAvailable == 0);
	}
	
	
	private static function testUncompressedCompression()
	{
		// Arrange
		var bytes = new ByteArray();
		bytes.writeByte(1);
		bytes.writeByte(2);
		bytes.writeByte(3);
		
		bytes.position = 0;
		
		var stream = new DeflateStream(UNCOMPRESSED, true);
		
		// Act
		stream.writeBlock(bytes, true);
		var result = stream.finalize();
		result.uncompress();
		
		// Assert
		assert(result.readByte() & 0xFF == 1);
		assert(result.readByte() & 0xFF == 2);
		assert(result.readByte() & 0xFF == 3);
		assert(result.bytesAvailable == 0);
	}
	
	
	private static function testManyByteCompression()
	{
		// Arrange
		var bytes = new ByteArray();
		for (i in 0 ... 44160) {		// Used to fail at >= 44160 (caused overflow)
			bytes.writeByte(i);
		}
		bytes.position = 0;
		
		var stream = new DeflateStream(FAST, true);
		
		// Act
		stream.writeBlock(bytes, true);
		var result = stream.finalize();
		result.uncompress();
		
		// Assert
		for (i in 0 ... 44160) {
			assert(result.readByte() & 0xFF == i & 0xFF);
		}
		assert(result.bytesAvailable == 0);
	}
	
	
	private static function testIntegerOverflow()
	{
		// Arrange
		var i = 0xFFFFFFFF;		// 32-bit int max
		
		// Act
		++i;
		
		// Assert
		assert(i == 0);
	}
	
	
	private static function testBufferOverflow()
	{
		// Arrange
		var bytes = new ByteArray();
		bytes.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
		Memory.select(bytes);
		
		// Act
		try {
			Memory.setByte(ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH + 99, 0xCC);
		}
		catch (e : Dynamic) {
			// Assert
			assert(bytes.length == ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH);
			return;
		}
		
		assert(false, "Exception was expected");
	}
	
	
	private static function testBufferResize()
	{
		// Arrange
		var bytes = new ByteArray();
		bytes.length = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH;
		Memory.select(bytes);
		
		// Act
		bytes.length += 32536;
		Memory.setByte(ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH + 32535, 0xCC);
		
		// Assert
		var newLength : UInt = ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH + 32536;
		assert(ApplicationDomain.currentDomain.domainMemory.length == newLength);
		assert(Memory.getByte(ApplicationDomain.MIN_DOMAIN_MEMORY_LENGTH + 32535) == 0xCC);
	}
	
	private static function assert(condition, message = "Assertion failed")
	{
		if (!condition) {
			throw message;
		}
	}
}