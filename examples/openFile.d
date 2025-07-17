import libsndfile.libsndfilebind;
import std.string : fromStringz, toStringz;
import std.stdio;

struct Data{
    SNDFILE* snd;
    SF_INFO info;
}

void main() {
    Data data;

    string nf= "/Users/uio/Music/_.wav";
    data.snd = sf_open(nf.toStringz(), SFM_READ, &data.info);

    // const(char)* nf = "/Users/uio/Music/_.wav";
    // data.snd = sf_open(nf, SFM_READ, &data.info);
    if (data.snd == null) {
        writeln("Erreur d'ouverture du fichier WAV : ", fromStringz(sf_strerror(null)));
    }
    writeln("opened with success, now sf_close");
    sf_close(data.snd);
}
