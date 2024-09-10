module oxywitleaf2csv;
//   Witleaf PuseOxymeter BIN format data decoder.

//
//   Copyright (C) Kirill Raguzin, 2024.
//
//   This program is free software; you can redistribute it and/or modify it
//   under the terms of the GNU General Public License as published by the
//   Free Software Foundation; either version 2, or (at your option) any later
//   version.
//
//   This program is distributed in the hope that it will be useful, but
//   WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
//   Public License for more details.
//

static immutable string PROGRAM_NAME = "Witleaf PulseOxymeter BIN format decoder";
static immutable string PROGRAM_VERSION = "1.0";

int main(string[] args)
{
    // --- Prepare Windows console ---
    version(Windows) {
        // Fix console encoding issues with nonlatin letters
        import core.sys.windows.wincon;
        auto OldConsoleCP = GetConsoleOutputCP();
        scope(exit) {
            // Restore the thing as it was on exit
            SetConsoleCP(OldConsoleCP);
            SetConsoleOutputCP(OldConsoleCP);
        }
        // Set UTF8 as current console encoding (or at least try to do so)
        SetConsoleCP(65001);
        SetConsoleOutputCP(65001);
        // Rename console title for convenience
        import core.sys.windows.wincon;
        import std.conv : wtext;
        SetConsoleTitle(wtext(PROGRAM_NAME~" - v"~PROGRAM_VERSION).ptr);
    }

    // --- Loading options ---
    string  filename;
    bool    version_info_request = false;
    bool    print_header = false;

    import std.stdio;
    import std.conv: ConvException;
    import std.getopt;
    import core.stdc.stdlib : EXIT_SUCCESS, EXIT_FAILURE;
    try {
        auto getoptResult = getopt(args, std.getopt.config.caseSensitive,
            "version|v",    "Print version information and exit",   &version_info_request,
            "header|H",     "Include CSV header line",              &print_header,
            "filename|f",   "Input file name selected",             &filename,
            );
        if (getoptResult.helpWanted) { // "-h" parameter
            defaultGetoptPrinter(
                "         --- Witleaf PulseOxymeter BIN format decoder ---\n"~
                "The program reads a BIN-file produced by Witleaf pulse-oxymeters and \n"~
                "produces a CSV-formatted output with the extracted data to stdout. \n"~
                "The columns are as follows: section(page), sample time, SpO2(%), \n"~
                "pulse rate (BPM). Field separator used is \";\".\n\n"~
                "Available command line options: ",
                getoptResult.options);
            return EXIT_SUCCESS;
        }
        if (version_info_request) {
            writeln(PROGRAM_NAME~" v"~PROGRAM_VERSION~".");
            writeln("(c) Kirill Raguzin, 2024.");
            return EXIT_SUCCESS;
        }
        if (!filename.length) with(stderr) {
            writeln("Input file name is not set! Run with -h option for more details.");
            return EXIT_FAILURE;
        }
    } catch (GetOptException e) {
        stderr.writeln(e.msg);
        return EXIT_FAILURE;
    } catch (ConvException e) {
        stderr.writeln("Can not parse the given parameters!");
        return EXIT_FAILURE;
    }

    try {
        import std.file : exists;
        if(!exists(filename)) throw new Exception("Input file not found!");
        auto input_file = File(filename, "rb");

        // -- Check the file ID --
        immutable char[12] FILE_ID = "ARSTN\0\0\0\0\0\0\0";
        char[12] ID;
        if ((input_file.rawRead(ID)).length != ID.length)
            throw new Exception("Input file header read error!");
        import std.algorithm.comparison : cmp;
        if (ID != FILE_ID) throw new Exception("Incorrect input file header!");

        // -- Metadata --
        import std.datetime;
        DateTime timestamp;
        Duration sample_timestep;
        ubyte section_idx = 0;

        void ReadSectionHeader()
        {
            union T_OxyWitleaf_SecHeader {
            align(1): // Packed
                ubyte[12] raw_data;
                struct {
                    ubyte[5] prefix; // ??? 0,1,1,1,1 ??? - Just ignore it for now...
                    ubyte timestep;  // In seconds
                    ubyte year;      // Add 2000 to get the actual value
                    ubyte month;
                    ubyte day;
                    ubyte hour;
                    ubyte minute;
                    ubyte second;
                }
                static assert (this.sizeof == 12, "Incorrect section header size!");
            }
            T_OxyWitleaf_SecHeader header;
            if ((input_file.rawRead(header.raw_data)).length != header.sizeof)
                throw new Exception("Input file section header read error!");
            with(header) {
                timestamp = DateTime(year+2000, month, day, hour, minute, second);
                sample_timestep = dur!"seconds"(timestep);
            }
            section_idx++;
        }

        // -- Processing the samples --
        ReadSectionHeader();
        if (print_header) {
            import std.conv : hexString;
            static immutable string UTF8_BOM = hexString!"EFBBBF";
            // BOM is required by M$ Excel and many other
            // Windows programs when UTF8 is used.
            writeln(UTF8_BOM~"Section;Timestamp;SpO2;PR");
        }
        while (!input_file.eof) {
            union T_OxyWitleaf_Sample {
            align(1): // Packed
                ubyte[4] raw_data;
                struct {
                    ubyte  SPO2; // In %.
                    ubyte  PR;   // In BPM.
                    ushort key;  // Must be equal to FFFF.
                }
                static assert (this.sizeof == 4, "Incorrect sample size!");
            }
            T_OxyWitleaf_Sample sample;
            if ((input_file.rawRead(sample.raw_data)).length != sample.sizeof) {
                // We expect a completely perfect file format here so it is
                // probably some residual junk at the end of the file or an EOF symbol.
                break; // Just ingnore it and stop processing as if nothing happened.
            }
            if (sample.key == 0xFFFF) {
                // Got a proper sample, continue with the current section
                writefln("%d;%s;%d;%d",
                    section_idx, timestamp.toISOExtString(), sample.SPO2, sample.PR);
                timestamp += sample_timestep;
            } else {
                // We hit a new section - reread the metadata
                input_file.seek(-long(T_OxyWitleaf_Sample.sizeof), SEEK_CUR);
                ReadSectionHeader();
            }
        }
    } catch(Exception e) {
        stderr.writeln("File ", filename, " processing error! ", e.msg);
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}
