function Add-D365BCDotNetHelperType {
    param( )
    begin {
        
    }
    process {
        $source = @"
using System;
using System.Collections.Generic;
using System.Linq;
using System.IO;

namespace D365BCAppHelper
{
    public class StreamHelper
    {
        private static long[] ReadOffsets = { 0, 40 };

        public static Stream DecodeStream(string filename, long offset)
        {
            Stream stream;
            using (FileStream fs = new FileStream(filename, FileMode.Open))
            {
                stream = DecodeStream(fs, offset);
                fs.Close();
            }
            return stream;
        }
        public static Stream DecodeStream(Stream stream, long offset, long headerLength = 8)
        {
            uint x = 0;
            uint y = 0;
            int read;
            byte[] key;
            byte[] buffer = new byte[81920];

            #region Prepare Key 
            // Prepare they Key to decode the Stream
            byte[] numArray = new byte[256];
            for (int index = 0; index < 256; ++index)
                numArray[index] = (byte)index;
            int index1 = 0;
            int index2 = 0;
            for (; index1 < 256; ++index1)
            {
                index2 = index2 + (int)KeySource[index1 % KeySource.Length] + (int)numArray[index1] & (int)byte.MaxValue;
                byte num = numArray[index1];
                numArray[index1] = numArray[index2];
                numArray[index2] = num;
            }
            key = numArray;
            #endregion

            // Prepare the source Stream, set Positon to 48 (Offset = 40; Header-length = 8)
            stream.Seek(offset + HeaderSource.Length, SeekOrigin.Begin);

            // Create new MemoryStream, which will contain the decoded Stream
            MemoryStream ms = new MemoryStream();

            // Only used as a placeholder
            int offsetPlaceholder = 0;
            while (ms.Length < (stream.Length - (offset + headerLength)))
            {
                read = stream.Read(buffer, 0, buffer.Length);
                if (read != 0)
                {
                    if (buffer == null)
                        throw new ArgumentNullException("buffer");

                    for (int index = 0; index < buffer.Length; ++index)
                    {
                        #region Update Mask 
                        x = (uint)((int)x + 1 & (int)byte.MaxValue);
                        y = (uint)((int)y + (int)key[(int)x] & (int)byte.MaxValue);
                        byte num = key[(int)x];
                        key[(int)x] = key[(int)y];
                        key[(int)y] = num;
                        byte value = key[(int)key[(int)x] + (int)key[(int)y] & (int)byte.MaxValue];
                        #endregion

                        buffer[offsetPlaceholder + index] = (byte)((uint)buffer[offsetPlaceholder + index] ^ (uint)value);
                    }

                    ms.Write(buffer, 0, read);
                }
            }
            return ms;
        }
        public static bool IsRuntimePackage(string filename, out long offset)
        {
            foreach (long currOffset in ReadOffsets)
            {
                offset = currOffset;
                if (IsRuntimePackageWithOffset(filename, offset))
                {
                    return true;
                }
            }

            offset = -1;
            return false;
        }
        public static bool IsRuntimePackage(Stream stream, out long offset)
        {
            foreach (long currOffset in ReadOffsets)
            {
                offset = currOffset;
                if (IsRuntimePackageWithOffset(stream, offset))
                {
                    return true;
                }
            }

            offset = -1;
            return false;
        }
        public static bool IsRuntimePackageWithOffset(string filename, long offset)
        {
            bool runtimePackage = false;
            using (FileStream fs = new FileStream(filename, FileMode.Open))
            {
                runtimePackage = IsRuntimePackageWithOffset(fs, offset);
                fs.Close();
            }
            return runtimePackage;
        }
        public static bool IsRuntimePackageWithOffset(Stream stream, long offset)
        {
            if (stream == null)
                throw new ArgumentNullException("stream");
            bool runtimePackage = false;
            if (stream.CanRead && stream.CanSeek && stream.Length >= (long)HeaderSource.Length)
            {
                long position = stream.Position;
                stream.Seek(position, SeekOrigin.Begin);
                stream.Seek(offset, SeekOrigin.Begin);
                try
                {
                    byte[] buffer = new byte[HeaderSource.Length];
                    int num = stream.Read(buffer, 0, buffer.Length);
                    if (buffer.Length == num)
                    {
                        if (((IEnumerable<byte>)buffer).SequenceEqual<byte>((IEnumerable<byte>)HeaderSource))
                            runtimePackage = true;
                    }
                }
                finally
                {
                    stream.Seek(position, SeekOrigin.Begin);
                }
            }
            return runtimePackage;
        }

        private static readonly byte[] KeySource = new byte[6]
        {
            (byte) 15,
            (byte) 11,
            (byte) 81,
            (byte) 137,
            (byte) 184,
            (byte) 120
        };

        private static readonly byte[] HeaderSource = new byte[8]
        {
            (byte) 46,
            (byte) 78,
            (byte) 69,
            (byte) 65,
            (byte) 0,
            (byte) 0,
            (byte) 0,
            (byte) 1
        };
    }
}        
"@
        Add-Type -TypeDefinition $source
    }
}
Add-D365BCDotNetHelperType