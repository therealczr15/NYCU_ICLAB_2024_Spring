# include <iostream>
# include <iomanip>
# include <fstream>

using namespace std;

int main()
{
	fstream out;
	out.open("dram.txt",ios::out);
	for(int i=0;i<256;i++)
	{
		if(i ==158)
		{
			
			out << "@10" << setw(3) << setfill('0') << hex << (i*8) << '\n';
			out << "01 00 00 00\n";
			out << "@10" << setw(3) << setfill('0') << hex << (i*8+4) << '\n'; 
			out << "01 00 00 00\n";
		}
		else 
		{
			out << "@10" << setw(3) << setfill('0') << hex << (i*8) << '\n';
			out << "01 ff ff ff\n";
			out << "@10" << setw(3) << setfill('0') << hex << (i*8+4) << '\n'; 
			out << "01 ff ff ff\n";
		}
	}
	return 0;
}
