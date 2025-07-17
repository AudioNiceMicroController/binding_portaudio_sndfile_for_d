module libsndfile.libsndfilebind;

// http://www.mega-nerd.com/libsndfile/api.html

extern (C):

alias sf_count_t = long;

struct SF_INFO {
    sf_count_t frames;
    int samplerate;
    int channels;
    int format;
    int sections;
    int seekable;
}

struct SF_VIRTUAL_IO {
    sf_count_t function1;
    sf_count_t function2;
    sf_count_t function3;
    sf_count_t function4;
    sf_count_t function5;
}

alias SNDFILE = void;

enum
{
    SFM_READ = 0x10,
    SFM_WRITE = 0x20,
    SFM_RDWR = 0x30
}

enum SF_FORMAT {
    WAV         = 0x010000,
    AIFF        = 0x020000,
    AU          = 0x030000,
    RAW         = 0x040000,
    PAF         = 0x050000,
    SVX         = 0x060000,
    NIST        = 0x070000,
    VOC         = 0x080000,
    IRCAM       = 0x0A0000,
    W64         = 0x0B0000,
    MAT4        = 0x0C0000,
    MAT5        = 0x0D0000,
    PVF         = 0x0E0000,
    XI          = 0x0F0000,
    HTK         = 0x100000,
    SDS         = 0x110000,
    AVR         = 0x120000,
    WAVEX       = 0x130000,
    SD2         = 0x160000,
    FLAC        = 0x170000,
    CAF         = 0x180000,
    WVE         = 0x190000,
    OGG         = 0x200000,
    MPC2K       = 0x210000,
    RF64        = 0x220000,

    PCM_S8      = 0x0001,
    PCM_16      = 0x0002,
    PCM_24      = 0x0003,
    PCM_32      = 0x0004,
    PCM_U8      = 0x0005,
    FLOAT       = 0x0006,
    DOUBLE      = 0x0007,
    ULAW        = 0x0010,
    ALAW        = 0x0011,
    IMA_ADPCM   = 0x0012,
    MS_ADPCM    = 0x0013,
    GSM610      = 0x0020,
    VOX_ADPCM   = 0x0021,
    G721_32     = 0x0030,
    G723_24     = 0x0031,
    G723_40     = 0x0032,
    DWVW_12     = 0x0040,
    DWVW_16     = 0x0041,
    DWVW_24     = 0x0042,
    DWVW_N      = 0x0043,
    DPCM_8      = 0x0050,
    DPCM_16     = 0x0051,
    VORBIS      = 0x0060,

    ENDIAN_FILE   = 0x00000000,
    ENDIAN_LITTLE = 0x10000000,
    ENDIAN_BIG    = 0x20000000,
    ENDIAN_CPU    = 0x30000000,

    SUBMASK      = 0x0000FFFF,
    TYPEMASK     = 0x0FFF0000,
    ENDMASK      = 0x30000000
}

enum SF_ERR {
    NO_ERROR             = 0,
    UNRECOGNISED_FORMAT  = 1,
    SYSTEM               = 2,
    MALFORMED_FILE       = 3,
    UNSUPPORTED_ENCODING = 4
}

// Function declarations

SNDFILE* sf_open(const char* path, int mode, SF_INFO* sfinfo);
SNDFILE* sf_wchar_open(const wchar* wpath, int mode, SF_INFO* sfinfo);
SNDFILE* sf_open_fd(int fd, int mode, SF_INFO* sfinfo, int close_desc);
SNDFILE* sf_open_virtual(SF_VIRTUAL_IO* sfvirtual, int mode, SF_INFO* sfinfo, void* user_data);

int sf_format_check(const SF_INFO* info);

sf_count_t sf_seek(SNDFILE* sndfile, sf_count_t frames, int whence);
int sf_command(SNDFILE* sndfile, int cmd, void* data, int datasize);

int sf_error(SNDFILE* sndfile);
const(char)* sf_strerror(SNDFILE* sndfile);
const(char)* sf_error_number(int errnum);
int sf_perror(SNDFILE* sndfile);
int sf_error_str(SNDFILE* sndfile, char* str, size_t len);

int sf_close(SNDFILE* sndfile);
void sf_write_sync(SNDFILE* sndfile);

sf_count_t sf_read_short(SNDFILE* sndfile, short* ptr, sf_count_t items);
sf_count_t sf_read_int(SNDFILE* sndfile, int* ptr, sf_count_t items);
sf_count_t sf_read_float(SNDFILE* sndfile, float* ptr, sf_count_t items);
sf_count_t sf_read_double(SNDFILE* sndfile, double* ptr, sf_count_t items);

sf_count_t sf_readf_short(SNDFILE* sndfile, short* ptr, sf_count_t frames);
sf_count_t sf_readf_int(SNDFILE* sndfile, int* ptr, sf_count_t frames);
sf_count_t sf_readf_float(SNDFILE* sndfile, float* ptr, sf_count_t frames);
sf_count_t sf_readf_double(SNDFILE* sndfile, double* ptr, sf_count_t frames);

sf_count_t sf_write_short(SNDFILE* sndfile, short* ptr, sf_count_t items);
sf_count_t sf_write_int(SNDFILE* sndfile, int* ptr, sf_count_t items);
sf_count_t sf_write_float(SNDFILE* sndfile, float* ptr, sf_count_t items);
sf_count_t sf_write_double(SNDFILE* sndfile, double* ptr, sf_count_t items);

sf_count_t sf_writef_short(SNDFILE* sndfile, short* ptr, sf_count_t frames);
sf_count_t sf_writef_int(SNDFILE* sndfile, int* ptr, sf_count_t frames);
sf_count_t sf_writef_float(SNDFILE* sndfile, float* ptr, sf_count_t frames);
sf_count_t sf_writef_double(SNDFILE* sndfile, double* ptr, sf_count_t frames);

sf_count_t sf_read_raw(SNDFILE* sndfile, void* ptr, sf_count_t bytes);
sf_count_t sf_write_raw(SNDFILE* sndfile, void* ptr, sf_count_t bytes);

const(char)* sf_get_string(SNDFILE* sndfile, int str_type);
int sf_set_string(SNDFILE* sndfile, int str_type, const char* str);
