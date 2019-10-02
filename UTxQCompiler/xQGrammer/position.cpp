using namespace std;

// Position:
// Describes a source position including the file, line, and
// column location. A Position is valid if the line_no is > 0.
//
typedef struct {
    string fileName;
    int offset;
    int line, column;
    //
    // isValidPos(): Returns true if position is valid.
    //
    bool isValidPosi(){ return (line > 0); }
    //
    // posToString(): Returns a string in on of the formats below:-
    //	file:line:column    valid position with file name and column
    //	file:line           valid position with file name only (column == 0)
    //	line:column         valid position without file name
    //	line                valid position only
    //	file                invalid position with file name
    //	-                   invalid position without file name
    //
    string posToString(){
        string st = fileName;
        if(isValidPosi()){
            if(st!=""){
                st+=":";
            }
            st+=to_string(line);
            if(column!=0){
                st+=":"+to_string(column);
            }
        }
        if(st==""){
            st="-";
        }
        return st;
    }
} Position;
//
// Pos: Short description of source position within a file set.
// It can be converted into a Position for a more convenient and
// lengthy description.
//
// Pos for a given file is a number in range [base, base+size],
// specified when adding the file to the file set with addFile().
//
// To create the Pos value for a specific source offset (measured in bytes),
// first add the respective file to the current file set using FileSet.addFile
// and then call File.Pos(offset) for that file. Given a Pos value p
// for a specific file set fset, the corresponding Position value is
// obtained by calling fset.Position(p).
//
// Pos values can be compared directly with the usual comparison operators:
// If two Pos values p and q are in the same file, comparing p and q is
// equivalent to comparing the respective source file offsets. If p and q
// are in different files, p < q is true if the file implied by p was added
// to the respective file set before the file implied by q.
//
typedef int Pos;
//
// NoPos: No file and line information associated with it, isValidPos(NoPos)
// is false. NoPos is always smaller than any other Pos value. Position value
// of NoPos is the zero value for Position.
//
const Pos NoPos = 0;
//
// isValidPos(): Returns true if the position is valid.
//
bool isValidPos(Pos p){
    return (p != NoPos);
}
//
// lineInfo: Object describes alternative file, line, and column
// number information (like info by //line directive) for a 
// given file offset.
//
typedef struct {
    int offset;
	string fileName;
	int line, column;
} lineInfo;
// -----------------------------------------------------------------------------
// File:
// A handle for a file belonging to a FileSet.
// It has a name, size, and line offset table.
//
typedef struct {
    string name;
    int base;
    int size;
    mutex mtx; // lines and infos are protected by mutex
    vector<int> lines; // contains offset of the first character for each line (the first entry is always 0)
	vector<lineInfo> infos;
    //
    // Name(): Returns filename of the file registered with addFile.
    //
    string Name(){ return name; }
    //
    // Base(): Returns base offset of the file registered with addFile.
    //
    int Base(){ return base; }
    //
    // Size(): Returns size of the file registered with addFile.
    //
    int Size(){ return size; }
    //
    // lineCount(): Returns number of lines in the file.
    //
    int lineCount(){
        mtx.lock();
        int val = lines.size();
        mtx.unlock();
        return val;
    }
    // addLine(): Adds line offset for a new line.
    // line offset (> previous_line_offset and < file_size).
    // Else the line offset is ignored.
    //
    void addLine(int offset) {
        mtx.lock();
        int l = lines.size();
        if((l == 0 || lines[l-1] < offset) && (offset < size)){
            lines.push_back(offset);
        }
        mtx.unlock();
    }
    // mergeLine(): Merges a line with the following line and replaces
    // the newline char ('\n') with a space ('\0'). To obtain the line
    // number, consult e.g. Position.line. mergeLine() will panic if 
    // invalid line number is given.
    //
    void mergeLine(int line) {
        if(line<1){
            cerr<<"Invalid line number: Must be greater than 0\n";
            return;
        }
        mtx.lock();
        int len=lines.size();
	    if(line>=len){
            cerr<<"!!Invalid line number!!\n";
            mtx.unlock(); return;
        }
	    // To merge the line <l> with the line <l+1>, we need to remove
        // the entry in lines[l] because of 0-based indexing in lines.
	    for(int i=line;i<len-1;i++){
            lines[i]=lines[i+1];
        }
        lines.pop_back();
        mtx.unlock(); return;
    }
} File;