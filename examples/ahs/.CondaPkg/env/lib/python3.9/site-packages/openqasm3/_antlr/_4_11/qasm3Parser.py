# Generated from qasm3Parser.g4 by ANTLR 4.11.1
# encoding: utf-8
from antlr4 import *
from io import StringIO
import sys
if sys.version_info[1] > 5:
	from typing import TextIO
else:
	from typing.io import TextIO

def serializedATN():
    return [
        4,1,109,798,2,0,7,0,2,1,7,1,2,2,7,2,2,3,7,3,2,4,7,4,2,5,7,5,2,6,
        7,6,2,7,7,7,2,8,7,8,2,9,7,9,2,10,7,10,2,11,7,11,2,12,7,12,2,13,7,
        13,2,14,7,14,2,15,7,15,2,16,7,16,2,17,7,17,2,18,7,18,2,19,7,19,2,
        20,7,20,2,21,7,21,2,22,7,22,2,23,7,23,2,24,7,24,2,25,7,25,2,26,7,
        26,2,27,7,27,2,28,7,28,2,29,7,29,2,30,7,30,2,31,7,31,2,32,7,32,2,
        33,7,33,2,34,7,34,2,35,7,35,2,36,7,36,2,37,7,37,2,38,7,38,2,39,7,
        39,2,40,7,40,2,41,7,41,2,42,7,42,2,43,7,43,2,44,7,44,2,45,7,45,2,
        46,7,46,2,47,7,47,2,48,7,48,2,49,7,49,2,50,7,50,2,51,7,51,2,52,7,
        52,2,53,7,53,2,54,7,54,2,55,7,55,2,56,7,56,2,57,7,57,2,58,7,58,2,
        59,7,59,2,60,7,60,2,61,7,61,2,62,7,62,2,63,7,63,1,0,3,0,130,8,0,
        1,0,5,0,133,8,0,10,0,12,0,136,9,0,1,0,1,0,1,1,1,1,1,1,1,1,1,2,1,
        2,5,2,146,8,2,10,2,12,2,149,9,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,
        1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,
        1,2,1,2,1,2,1,2,3,2,179,8,2,3,2,181,8,2,1,3,1,3,3,3,185,8,3,1,4,
        1,4,5,4,189,8,4,10,4,12,4,192,9,4,1,4,1,4,1,5,1,5,1,5,1,6,1,6,3,
        6,201,8,6,1,7,1,7,1,7,1,7,1,8,1,8,1,8,1,8,1,9,1,9,1,9,1,10,1,10,
        1,10,1,11,1,11,1,11,1,12,1,12,1,12,1,12,1,12,1,12,1,12,1,12,1,12,
        1,12,3,12,230,8,12,1,12,1,12,1,13,1,13,1,13,1,13,1,13,1,13,1,13,
        3,13,241,8,13,1,14,1,14,1,14,3,14,246,8,14,1,14,1,14,1,15,1,15,1,
        15,1,15,1,15,1,15,1,16,1,16,3,16,258,8,16,1,16,1,16,1,17,1,17,3,
        17,264,8,17,1,17,1,17,1,18,1,18,1,18,3,18,271,8,18,1,18,1,18,1,19,
        5,19,276,8,19,10,19,12,19,279,9,19,1,19,1,19,1,19,3,19,284,8,19,
        1,19,3,19,287,8,19,1,19,3,19,290,8,19,1,19,1,19,1,19,1,19,5,19,296,
        8,19,10,19,12,19,299,9,19,1,19,1,19,1,19,3,19,304,8,19,1,19,3,19,
        307,8,19,1,19,3,19,310,8,19,1,19,3,19,313,8,19,1,19,3,19,316,8,19,
        1,20,1,20,1,20,3,20,321,8,20,1,20,1,20,1,21,1,21,1,21,1,21,1,22,
        1,22,1,22,1,22,1,22,1,22,1,23,1,23,3,23,337,8,23,1,23,1,23,1,23,
        3,23,342,8,23,1,23,1,23,1,24,1,24,1,24,1,24,1,24,1,24,1,24,1,25,
        1,25,1,25,3,25,356,8,25,1,25,1,25,1,25,1,26,1,26,1,26,3,26,364,8,
        26,1,26,1,26,1,27,1,27,1,27,1,27,1,28,1,28,1,28,1,28,3,28,376,8,
        28,1,28,1,28,3,28,380,8,28,1,28,1,28,1,29,1,29,1,29,1,29,3,29,388,
        8,29,1,29,1,29,3,29,392,8,29,1,29,1,29,1,30,1,30,1,30,1,30,3,30,
        400,8,30,1,30,3,30,403,8,30,1,30,1,30,1,30,1,31,1,31,1,31,1,31,3,
        31,412,8,31,1,31,1,31,1,32,1,32,1,32,1,33,1,33,1,33,3,33,422,8,33,
        1,33,1,33,1,34,1,34,1,34,1,34,3,34,430,8,34,1,34,3,34,433,8,34,1,
        34,1,34,3,34,437,8,34,1,34,1,34,3,34,441,8,34,1,34,1,34,1,35,1,35,
        1,35,1,35,1,35,1,35,1,35,1,35,1,35,3,35,454,8,35,1,35,1,35,1,35,
        1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,3,35,468,8,35,1,35,
        1,35,3,35,472,8,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,
        1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,
        1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,1,35,
        5,35,509,8,35,10,35,12,35,512,9,35,1,36,1,36,1,36,5,36,517,8,36,
        10,36,12,36,520,9,36,1,37,1,37,1,37,3,37,525,8,37,1,38,1,38,1,38,
        1,39,3,39,531,8,39,1,39,1,39,3,39,535,8,39,1,39,1,39,3,39,539,8,
        39,1,40,1,40,1,40,1,40,5,40,545,8,40,10,40,12,40,548,9,40,1,40,3,
        40,551,8,40,1,40,1,40,1,41,1,41,1,41,3,41,558,8,41,1,41,1,41,1,41,
        3,41,563,8,41,5,41,565,8,41,10,41,12,41,568,9,41,1,41,3,41,571,8,
        41,1,41,1,41,1,42,1,42,1,42,1,42,3,42,579,8,42,1,42,1,42,1,42,3,
        42,584,8,42,5,42,586,8,42,10,42,12,42,589,9,42,1,42,3,42,592,8,42,
        3,42,594,8,42,1,42,1,42,1,43,1,43,5,43,600,8,43,10,43,12,43,603,
        9,43,1,44,1,44,1,44,1,45,1,45,1,45,1,45,1,45,1,45,1,45,1,45,1,45,
        1,45,1,45,3,45,619,8,45,3,45,621,8,45,1,45,1,45,1,46,1,46,3,46,627,
        8,46,1,46,1,46,3,46,631,8,46,1,46,1,46,3,46,635,8,46,1,46,1,46,3,
        46,639,8,46,1,46,1,46,3,46,643,8,46,1,46,1,46,1,46,1,46,1,46,1,46,
        1,46,1,46,3,46,653,8,46,3,46,655,8,46,1,47,1,47,3,47,659,8,47,1,
        48,1,48,1,48,1,48,1,48,1,48,1,48,1,49,1,49,1,49,1,49,1,49,1,49,1,
        49,1,49,1,49,3,49,677,8,49,1,49,1,49,1,50,1,50,1,50,1,50,1,51,1,
        51,1,52,1,52,3,52,689,8,52,1,53,1,53,1,54,1,54,3,54,695,8,54,1,55,
        1,55,1,55,1,55,3,55,701,8,55,3,55,703,8,55,1,56,1,56,1,56,1,56,1,
        56,1,56,1,56,1,56,1,56,3,56,714,8,56,1,56,1,56,1,56,3,56,719,8,56,
        1,57,1,57,1,57,5,57,724,8,57,10,57,12,57,727,9,57,1,57,3,57,730,
        8,57,1,58,1,58,1,58,5,58,735,8,58,10,58,12,58,738,9,58,1,58,3,58,
        741,8,58,1,59,1,59,1,59,5,59,746,8,59,10,59,12,59,749,9,59,1,59,
        3,59,752,8,59,1,60,1,60,1,60,5,60,757,8,60,10,60,12,60,760,9,60,
        1,60,3,60,763,8,60,1,61,1,61,1,61,5,61,768,8,61,10,61,12,61,771,
        9,61,1,61,3,61,774,8,61,1,62,1,62,1,62,5,62,779,8,62,10,62,12,62,
        782,9,62,1,62,3,62,785,8,62,1,63,1,63,1,63,5,63,790,8,63,10,63,12,
        63,793,9,63,1,63,3,63,796,8,63,1,63,0,1,70,64,0,2,4,6,8,10,12,14,
        16,18,20,22,24,26,28,30,32,34,36,38,40,42,44,46,48,50,52,54,56,58,
        60,62,64,66,68,70,72,74,76,78,80,82,84,86,88,90,92,94,96,98,100,
        102,104,106,108,110,112,114,116,118,120,122,124,126,0,11,1,0,22,
        23,2,0,27,27,29,29,2,0,63,63,81,81,2,0,67,67,78,79,2,0,52,52,85,
        94,2,0,68,68,70,71,2,0,65,65,67,67,1,0,44,45,1,0,25,26,2,0,48,50,
        90,90,1,0,90,91,881,0,129,1,0,0,0,2,139,1,0,0,0,4,180,1,0,0,0,6,
        182,1,0,0,0,8,186,1,0,0,0,10,195,1,0,0,0,12,200,1,0,0,0,14,202,1,
        0,0,0,16,206,1,0,0,0,18,210,1,0,0,0,20,213,1,0,0,0,22,216,1,0,0,
        0,24,219,1,0,0,0,26,233,1,0,0,0,28,242,1,0,0,0,30,249,1,0,0,0,32,
        255,1,0,0,0,34,261,1,0,0,0,36,267,1,0,0,0,38,315,1,0,0,0,40,317,
        1,0,0,0,42,324,1,0,0,0,44,328,1,0,0,0,46,336,1,0,0,0,48,345,1,0,
        0,0,50,352,1,0,0,0,52,360,1,0,0,0,54,367,1,0,0,0,56,371,1,0,0,0,
        58,383,1,0,0,0,60,395,1,0,0,0,62,407,1,0,0,0,64,415,1,0,0,0,66,418,
        1,0,0,0,68,425,1,0,0,0,70,471,1,0,0,0,72,513,1,0,0,0,74,524,1,0,
        0,0,76,526,1,0,0,0,78,530,1,0,0,0,80,540,1,0,0,0,82,554,1,0,0,0,
        84,574,1,0,0,0,86,597,1,0,0,0,88,604,1,0,0,0,90,620,1,0,0,0,92,654,
        1,0,0,0,94,656,1,0,0,0,96,660,1,0,0,0,98,667,1,0,0,0,100,680,1,0,
        0,0,102,684,1,0,0,0,104,688,1,0,0,0,106,690,1,0,0,0,108,694,1,0,
        0,0,110,702,1,0,0,0,112,718,1,0,0,0,114,720,1,0,0,0,116,731,1,0,
        0,0,118,742,1,0,0,0,120,753,1,0,0,0,122,764,1,0,0,0,124,775,1,0,
        0,0,126,786,1,0,0,0,128,130,3,2,1,0,129,128,1,0,0,0,129,130,1,0,
        0,0,130,134,1,0,0,0,131,133,3,4,2,0,132,131,1,0,0,0,133,136,1,0,
        0,0,134,132,1,0,0,0,134,135,1,0,0,0,135,137,1,0,0,0,136,134,1,0,
        0,0,137,138,5,0,0,1,138,1,1,0,0,0,139,140,5,1,0,0,140,141,5,101,
        0,0,141,142,5,60,0,0,142,3,1,0,0,0,143,181,3,10,5,0,144,146,3,6,
        3,0,145,144,1,0,0,0,146,149,1,0,0,0,147,145,1,0,0,0,147,148,1,0,
        0,0,148,178,1,0,0,0,149,147,1,0,0,0,150,179,3,44,22,0,151,179,3,
        62,31,0,152,179,3,32,16,0,153,179,3,34,17,0,154,179,3,18,9,0,155,
        179,3,66,33,0,156,179,3,14,7,0,157,179,3,46,23,0,158,179,3,48,24,
        0,159,179,3,20,10,0,160,179,3,56,28,0,161,179,3,68,34,0,162,179,
        3,36,18,0,163,179,3,22,11,0,164,179,3,64,32,0,165,179,3,58,29,0,
        166,179,3,24,12,0,167,179,3,38,19,0,168,179,3,60,30,0,169,179,3,
        26,13,0,170,179,3,16,8,0,171,179,3,50,25,0,172,179,3,40,20,0,173,
        179,3,52,26,0,174,179,3,54,27,0,175,179,3,42,21,0,176,179,3,28,14,
        0,177,179,3,30,15,0,178,150,1,0,0,0,178,151,1,0,0,0,178,152,1,0,
        0,0,178,153,1,0,0,0,178,154,1,0,0,0,178,155,1,0,0,0,178,156,1,0,
        0,0,178,157,1,0,0,0,178,158,1,0,0,0,178,159,1,0,0,0,178,160,1,0,
        0,0,178,161,1,0,0,0,178,162,1,0,0,0,178,163,1,0,0,0,178,164,1,0,
        0,0,178,165,1,0,0,0,178,166,1,0,0,0,178,167,1,0,0,0,178,168,1,0,
        0,0,178,169,1,0,0,0,178,170,1,0,0,0,178,171,1,0,0,0,178,172,1,0,
        0,0,178,173,1,0,0,0,178,174,1,0,0,0,178,175,1,0,0,0,178,176,1,0,
        0,0,178,177,1,0,0,0,179,181,1,0,0,0,180,143,1,0,0,0,180,147,1,0,
        0,0,181,5,1,0,0,0,182,184,5,21,0,0,183,185,5,104,0,0,184,183,1,0,
        0,0,184,185,1,0,0,0,185,7,1,0,0,0,186,190,5,55,0,0,187,189,3,4,2,
        0,188,187,1,0,0,0,189,192,1,0,0,0,190,188,1,0,0,0,190,191,1,0,0,
        0,191,193,1,0,0,0,192,190,1,0,0,0,193,194,5,56,0,0,194,9,1,0,0,0,
        195,196,5,20,0,0,196,197,5,104,0,0,197,11,1,0,0,0,198,201,3,4,2,
        0,199,201,3,8,4,0,200,198,1,0,0,0,200,199,1,0,0,0,201,13,1,0,0,0,
        202,203,5,3,0,0,203,204,5,95,0,0,204,205,5,60,0,0,205,15,1,0,0,0,
        206,207,5,2,0,0,207,208,5,95,0,0,208,209,5,60,0,0,209,17,1,0,0,0,
        210,211,5,11,0,0,211,212,5,60,0,0,212,19,1,0,0,0,213,214,5,12,0,
        0,214,215,5,60,0,0,215,21,1,0,0,0,216,217,5,15,0,0,217,218,5,60,
        0,0,218,23,1,0,0,0,219,220,5,17,0,0,220,221,3,92,46,0,221,222,5,
        90,0,0,222,229,5,19,0,0,223,230,3,80,40,0,224,225,5,53,0,0,225,226,
        3,78,39,0,226,227,5,54,0,0,227,230,1,0,0,0,228,230,5,90,0,0,229,
        223,1,0,0,0,229,224,1,0,0,0,229,228,1,0,0,0,230,231,1,0,0,0,231,
        232,3,12,6,0,232,25,1,0,0,0,233,234,5,13,0,0,234,235,5,57,0,0,235,
        236,3,70,35,0,236,237,5,58,0,0,237,240,3,12,6,0,238,239,5,14,0,0,
        239,241,3,12,6,0,240,238,1,0,0,0,240,241,1,0,0,0,241,27,1,0,0,0,
        242,245,5,16,0,0,243,246,3,70,35,0,244,246,3,76,38,0,245,243,1,0,
        0,0,245,244,1,0,0,0,245,246,1,0,0,0,246,247,1,0,0,0,247,248,5,60,
        0,0,248,29,1,0,0,0,249,250,5,18,0,0,250,251,5,57,0,0,251,252,3,70,
        35,0,252,253,5,58,0,0,253,254,3,12,6,0,254,31,1,0,0,0,255,257,5,
        51,0,0,256,258,3,124,62,0,257,256,1,0,0,0,257,258,1,0,0,0,258,259,
        1,0,0,0,259,260,5,60,0,0,260,33,1,0,0,0,261,263,5,9,0,0,262,264,
        3,100,50,0,263,262,1,0,0,0,263,264,1,0,0,0,264,265,1,0,0,0,265,266,
        3,8,4,0,266,35,1,0,0,0,267,268,5,48,0,0,268,270,3,100,50,0,269,271,
        3,124,62,0,270,269,1,0,0,0,270,271,1,0,0,0,271,272,1,0,0,0,272,273,
        5,60,0,0,273,37,1,0,0,0,274,276,3,90,45,0,275,274,1,0,0,0,276,279,
        1,0,0,0,277,275,1,0,0,0,277,278,1,0,0,0,278,280,1,0,0,0,279,277,
        1,0,0,0,280,286,5,90,0,0,281,283,5,57,0,0,282,284,3,120,60,0,283,
        282,1,0,0,0,283,284,1,0,0,0,284,285,1,0,0,0,285,287,5,58,0,0,286,
        281,1,0,0,0,286,287,1,0,0,0,287,289,1,0,0,0,288,290,3,100,50,0,289,
        288,1,0,0,0,289,290,1,0,0,0,290,291,1,0,0,0,291,292,3,124,62,0,292,
        293,5,60,0,0,293,316,1,0,0,0,294,296,3,90,45,0,295,294,1,0,0,0,296,
        299,1,0,0,0,297,295,1,0,0,0,297,298,1,0,0,0,298,300,1,0,0,0,299,
        297,1,0,0,0,300,306,5,41,0,0,301,303,5,57,0,0,302,304,3,120,60,0,
        303,302,1,0,0,0,303,304,1,0,0,0,304,305,1,0,0,0,305,307,5,58,0,0,
        306,301,1,0,0,0,306,307,1,0,0,0,307,309,1,0,0,0,308,310,3,100,50,
        0,309,308,1,0,0,0,309,310,1,0,0,0,310,312,1,0,0,0,311,313,3,124,
        62,0,312,311,1,0,0,0,312,313,1,0,0,0,313,314,1,0,0,0,314,316,5,60,
        0,0,315,277,1,0,0,0,315,297,1,0,0,0,316,39,1,0,0,0,317,320,3,76,
        38,0,318,319,5,64,0,0,319,321,3,86,43,0,320,318,1,0,0,0,320,321,
        1,0,0,0,321,322,1,0,0,0,322,323,5,60,0,0,323,41,1,0,0,0,324,325,
        5,49,0,0,325,326,3,108,54,0,326,327,5,60,0,0,327,43,1,0,0,0,328,
        329,5,10,0,0,329,330,5,90,0,0,330,331,5,63,0,0,331,332,3,72,36,0,
        332,333,5,60,0,0,333,45,1,0,0,0,334,337,3,92,46,0,335,337,3,96,48,
        0,336,334,1,0,0,0,336,335,1,0,0,0,337,338,1,0,0,0,338,341,5,90,0,
        0,339,340,5,63,0,0,340,342,3,74,37,0,341,339,1,0,0,0,341,342,1,0,
        0,0,342,343,1,0,0,0,343,344,5,60,0,0,344,47,1,0,0,0,345,346,5,24,
        0,0,346,347,3,92,46,0,347,348,5,90,0,0,348,349,5,63,0,0,349,350,
        3,74,37,0,350,351,5,60,0,0,351,49,1,0,0,0,352,355,7,0,0,0,353,356,
        3,92,46,0,354,356,3,96,48,0,355,353,1,0,0,0,355,354,1,0,0,0,356,
        357,1,0,0,0,357,358,5,90,0,0,358,359,5,60,0,0,359,51,1,0,0,0,360,
        361,7,1,0,0,361,363,5,90,0,0,362,364,3,100,50,0,363,362,1,0,0,0,
        363,364,1,0,0,0,364,365,1,0,0,0,365,366,5,60,0,0,366,53,1,0,0,0,
        367,368,3,94,47,0,368,369,5,90,0,0,369,370,5,60,0,0,370,55,1,0,0,
        0,371,372,5,4,0,0,372,373,5,90,0,0,373,375,5,57,0,0,374,376,3,114,
        57,0,375,374,1,0,0,0,375,376,1,0,0,0,376,377,1,0,0,0,377,379,5,58,
        0,0,378,380,3,88,44,0,379,378,1,0,0,0,379,380,1,0,0,0,380,381,1,
        0,0,0,381,382,3,8,4,0,382,57,1,0,0,0,383,384,5,8,0,0,384,385,5,90,
        0,0,385,387,5,57,0,0,386,388,3,126,63,0,387,386,1,0,0,0,387,388,
        1,0,0,0,388,389,1,0,0,0,389,391,5,58,0,0,390,392,3,88,44,0,391,390,
        1,0,0,0,391,392,1,0,0,0,392,393,1,0,0,0,393,394,5,60,0,0,394,59,
        1,0,0,0,395,396,5,7,0,0,396,402,5,90,0,0,397,399,5,57,0,0,398,400,
        3,122,61,0,399,398,1,0,0,0,399,400,1,0,0,0,400,401,1,0,0,0,401,403,
        5,58,0,0,402,397,1,0,0,0,402,403,1,0,0,0,403,404,1,0,0,0,404,405,
        3,122,61,0,405,406,3,8,4,0,406,61,1,0,0,0,407,408,3,86,43,0,408,
        411,7,2,0,0,409,412,3,70,35,0,410,412,3,76,38,0,411,409,1,0,0,0,
        411,410,1,0,0,0,412,413,1,0,0,0,413,414,5,60,0,0,414,63,1,0,0,0,
        415,416,3,70,35,0,416,417,5,60,0,0,417,65,1,0,0,0,418,419,5,5,0,
        0,419,421,5,55,0,0,420,422,5,109,0,0,421,420,1,0,0,0,421,422,1,0,
        0,0,422,423,1,0,0,0,423,424,5,56,0,0,424,67,1,0,0,0,425,426,5,6,
        0,0,426,432,3,102,51,0,427,429,5,57,0,0,428,430,3,116,58,0,429,428,
        1,0,0,0,429,430,1,0,0,0,430,431,1,0,0,0,431,433,5,58,0,0,432,427,
        1,0,0,0,432,433,1,0,0,0,433,434,1,0,0,0,434,436,3,118,59,0,435,437,
        3,88,44,0,436,435,1,0,0,0,436,437,1,0,0,0,437,438,1,0,0,0,438,440,
        5,55,0,0,439,441,5,109,0,0,440,439,1,0,0,0,440,441,1,0,0,0,441,442,
        1,0,0,0,442,443,5,56,0,0,443,69,1,0,0,0,444,445,6,35,-1,0,445,446,
        5,57,0,0,446,447,3,70,35,0,447,448,5,58,0,0,448,472,1,0,0,0,449,
        450,7,3,0,0,450,472,3,70,35,15,451,454,3,92,46,0,452,454,3,96,48,
        0,453,451,1,0,0,0,453,452,1,0,0,0,454,455,1,0,0,0,455,456,5,57,0,
        0,456,457,3,70,35,0,457,458,5,58,0,0,458,472,1,0,0,0,459,460,5,47,
        0,0,460,461,5,57,0,0,461,462,3,8,4,0,462,463,5,58,0,0,463,472,1,
        0,0,0,464,465,5,90,0,0,465,467,5,57,0,0,466,468,3,120,60,0,467,466,
        1,0,0,0,467,468,1,0,0,0,468,469,1,0,0,0,469,472,5,58,0,0,470,472,
        7,4,0,0,471,444,1,0,0,0,471,449,1,0,0,0,471,453,1,0,0,0,471,459,
        1,0,0,0,471,464,1,0,0,0,471,470,1,0,0,0,472,510,1,0,0,0,473,474,
        10,16,0,0,474,475,5,69,0,0,475,509,3,70,35,16,476,477,10,14,0,0,
        477,478,7,5,0,0,478,509,3,70,35,15,479,480,10,13,0,0,480,481,7,6,
        0,0,481,509,3,70,35,14,482,483,10,12,0,0,483,484,5,83,0,0,484,509,
        3,70,35,13,485,486,10,11,0,0,486,487,5,82,0,0,487,509,3,70,35,12,
        488,489,10,10,0,0,489,490,5,80,0,0,490,509,3,70,35,11,491,492,10,
        9,0,0,492,493,5,74,0,0,493,509,3,70,35,10,494,495,10,8,0,0,495,496,
        5,76,0,0,496,509,3,70,35,9,497,498,10,7,0,0,498,499,5,72,0,0,499,
        509,3,70,35,8,500,501,10,6,0,0,501,502,5,75,0,0,502,509,3,70,35,
        7,503,504,10,5,0,0,504,505,5,73,0,0,505,509,3,70,35,6,506,507,10,
        17,0,0,507,509,3,84,42,0,508,473,1,0,0,0,508,476,1,0,0,0,508,479,
        1,0,0,0,508,482,1,0,0,0,508,485,1,0,0,0,508,488,1,0,0,0,508,491,
        1,0,0,0,508,494,1,0,0,0,508,497,1,0,0,0,508,500,1,0,0,0,508,503,
        1,0,0,0,508,506,1,0,0,0,509,512,1,0,0,0,510,508,1,0,0,0,510,511,
        1,0,0,0,511,71,1,0,0,0,512,510,1,0,0,0,513,518,3,70,35,0,514,515,
        5,66,0,0,515,517,3,70,35,0,516,514,1,0,0,0,517,520,1,0,0,0,518,516,
        1,0,0,0,518,519,1,0,0,0,519,73,1,0,0,0,520,518,1,0,0,0,521,525,3,
        82,41,0,522,525,3,70,35,0,523,525,3,76,38,0,524,521,1,0,0,0,524,
        522,1,0,0,0,524,523,1,0,0,0,525,75,1,0,0,0,526,527,5,50,0,0,527,
        528,3,108,54,0,528,77,1,0,0,0,529,531,3,70,35,0,530,529,1,0,0,0,
        530,531,1,0,0,0,531,532,1,0,0,0,532,534,5,59,0,0,533,535,3,70,35,
        0,534,533,1,0,0,0,534,535,1,0,0,0,535,538,1,0,0,0,536,537,5,59,0,
        0,537,539,3,70,35,0,538,536,1,0,0,0,538,539,1,0,0,0,539,79,1,0,0,
        0,540,541,5,55,0,0,541,546,3,70,35,0,542,543,5,62,0,0,543,545,3,
        70,35,0,544,542,1,0,0,0,545,548,1,0,0,0,546,544,1,0,0,0,546,547,
        1,0,0,0,547,550,1,0,0,0,548,546,1,0,0,0,549,551,5,62,0,0,550,549,
        1,0,0,0,550,551,1,0,0,0,551,552,1,0,0,0,552,553,5,56,0,0,553,81,
        1,0,0,0,554,557,5,55,0,0,555,558,3,70,35,0,556,558,3,82,41,0,557,
        555,1,0,0,0,557,556,1,0,0,0,558,566,1,0,0,0,559,562,5,62,0,0,560,
        563,3,70,35,0,561,563,3,82,41,0,562,560,1,0,0,0,562,561,1,0,0,0,
        563,565,1,0,0,0,564,559,1,0,0,0,565,568,1,0,0,0,566,564,1,0,0,0,
        566,567,1,0,0,0,567,570,1,0,0,0,568,566,1,0,0,0,569,571,5,62,0,0,
        570,569,1,0,0,0,570,571,1,0,0,0,571,572,1,0,0,0,572,573,5,56,0,0,
        573,83,1,0,0,0,574,593,5,53,0,0,575,594,3,80,40,0,576,579,3,70,35,
        0,577,579,3,78,39,0,578,576,1,0,0,0,578,577,1,0,0,0,579,587,1,0,
        0,0,580,583,5,62,0,0,581,584,3,70,35,0,582,584,3,78,39,0,583,581,
        1,0,0,0,583,582,1,0,0,0,584,586,1,0,0,0,585,580,1,0,0,0,586,589,
        1,0,0,0,587,585,1,0,0,0,587,588,1,0,0,0,588,591,1,0,0,0,589,587,
        1,0,0,0,590,592,5,62,0,0,591,590,1,0,0,0,591,592,1,0,0,0,592,594,
        1,0,0,0,593,575,1,0,0,0,593,578,1,0,0,0,594,595,1,0,0,0,595,596,
        5,54,0,0,596,85,1,0,0,0,597,601,5,90,0,0,598,600,3,84,42,0,599,598,
        1,0,0,0,600,603,1,0,0,0,601,599,1,0,0,0,601,602,1,0,0,0,602,87,1,
        0,0,0,603,601,1,0,0,0,604,605,5,64,0,0,605,606,3,92,46,0,606,89,
        1,0,0,0,607,621,5,42,0,0,608,609,5,43,0,0,609,610,5,57,0,0,610,611,
        3,70,35,0,611,612,5,58,0,0,612,621,1,0,0,0,613,618,7,7,0,0,614,615,
        5,57,0,0,615,616,3,70,35,0,616,617,5,58,0,0,617,619,1,0,0,0,618,
        614,1,0,0,0,618,619,1,0,0,0,619,621,1,0,0,0,620,607,1,0,0,0,620,
        608,1,0,0,0,620,613,1,0,0,0,621,622,1,0,0,0,622,623,5,77,0,0,623,
        91,1,0,0,0,624,626,5,31,0,0,625,627,3,100,50,0,626,625,1,0,0,0,626,
        627,1,0,0,0,627,655,1,0,0,0,628,630,5,32,0,0,629,631,3,100,50,0,
        630,629,1,0,0,0,630,631,1,0,0,0,631,655,1,0,0,0,632,634,5,33,0,0,
        633,635,3,100,50,0,634,633,1,0,0,0,634,635,1,0,0,0,635,655,1,0,0,
        0,636,638,5,34,0,0,637,639,3,100,50,0,638,637,1,0,0,0,638,639,1,
        0,0,0,639,655,1,0,0,0,640,642,5,35,0,0,641,643,3,100,50,0,642,641,
        1,0,0,0,642,643,1,0,0,0,643,655,1,0,0,0,644,655,5,30,0,0,645,655,
        5,39,0,0,646,655,5,40,0,0,647,652,5,36,0,0,648,649,5,53,0,0,649,
        650,3,92,46,0,650,651,5,54,0,0,651,653,1,0,0,0,652,648,1,0,0,0,652,
        653,1,0,0,0,653,655,1,0,0,0,654,624,1,0,0,0,654,628,1,0,0,0,654,
        632,1,0,0,0,654,636,1,0,0,0,654,640,1,0,0,0,654,644,1,0,0,0,654,
        645,1,0,0,0,654,646,1,0,0,0,654,647,1,0,0,0,655,93,1,0,0,0,656,658,
        5,28,0,0,657,659,3,100,50,0,658,657,1,0,0,0,658,659,1,0,0,0,659,
        95,1,0,0,0,660,661,5,37,0,0,661,662,5,53,0,0,662,663,3,92,46,0,663,
        664,5,62,0,0,664,665,3,120,60,0,665,666,5,54,0,0,666,97,1,0,0,0,
        667,668,7,8,0,0,668,669,5,37,0,0,669,670,5,53,0,0,670,671,3,92,46,
        0,671,676,5,62,0,0,672,677,3,120,60,0,673,674,5,46,0,0,674,675,5,
        63,0,0,675,677,3,70,35,0,676,672,1,0,0,0,676,673,1,0,0,0,677,678,
        1,0,0,0,678,679,5,54,0,0,679,99,1,0,0,0,680,681,5,53,0,0,681,682,
        3,70,35,0,682,683,5,54,0,0,683,101,1,0,0,0,684,685,7,9,0,0,685,103,
        1,0,0,0,686,689,3,70,35,0,687,689,3,112,56,0,688,686,1,0,0,0,688,
        687,1,0,0,0,689,105,1,0,0,0,690,691,7,10,0,0,691,107,1,0,0,0,692,
        695,3,86,43,0,693,695,5,91,0,0,694,692,1,0,0,0,694,693,1,0,0,0,695,
        109,1,0,0,0,696,703,3,92,46,0,697,703,3,98,49,0,698,700,5,29,0,0,
        699,701,3,100,50,0,700,699,1,0,0,0,700,701,1,0,0,0,701,703,1,0,0,
        0,702,696,1,0,0,0,702,697,1,0,0,0,702,698,1,0,0,0,703,111,1,0,0,
        0,704,705,3,92,46,0,705,706,5,90,0,0,706,719,1,0,0,0,707,708,3,94,
        47,0,708,709,5,90,0,0,709,719,1,0,0,0,710,711,7,1,0,0,711,713,5,
        90,0,0,712,714,3,100,50,0,713,712,1,0,0,0,713,714,1,0,0,0,714,719,
        1,0,0,0,715,716,3,98,49,0,716,717,5,90,0,0,717,719,1,0,0,0,718,704,
        1,0,0,0,718,707,1,0,0,0,718,710,1,0,0,0,718,715,1,0,0,0,719,113,
        1,0,0,0,720,725,3,112,56,0,721,722,5,62,0,0,722,724,3,112,56,0,723,
        721,1,0,0,0,724,727,1,0,0,0,725,723,1,0,0,0,725,726,1,0,0,0,726,
        729,1,0,0,0,727,725,1,0,0,0,728,730,5,62,0,0,729,728,1,0,0,0,729,
        730,1,0,0,0,730,115,1,0,0,0,731,736,3,104,52,0,732,733,5,62,0,0,
        733,735,3,104,52,0,734,732,1,0,0,0,735,738,1,0,0,0,736,734,1,0,0,
        0,736,737,1,0,0,0,737,740,1,0,0,0,738,736,1,0,0,0,739,741,5,62,0,
        0,740,739,1,0,0,0,740,741,1,0,0,0,741,117,1,0,0,0,742,747,3,106,
        53,0,743,744,5,62,0,0,744,746,3,106,53,0,745,743,1,0,0,0,746,749,
        1,0,0,0,747,745,1,0,0,0,747,748,1,0,0,0,748,751,1,0,0,0,749,747,
        1,0,0,0,750,752,5,62,0,0,751,750,1,0,0,0,751,752,1,0,0,0,752,119,
        1,0,0,0,753,758,3,70,35,0,754,755,5,62,0,0,755,757,3,70,35,0,756,
        754,1,0,0,0,757,760,1,0,0,0,758,756,1,0,0,0,758,759,1,0,0,0,759,
        762,1,0,0,0,760,758,1,0,0,0,761,763,5,62,0,0,762,761,1,0,0,0,762,
        763,1,0,0,0,763,121,1,0,0,0,764,769,5,90,0,0,765,766,5,62,0,0,766,
        768,5,90,0,0,767,765,1,0,0,0,768,771,1,0,0,0,769,767,1,0,0,0,769,
        770,1,0,0,0,770,773,1,0,0,0,771,769,1,0,0,0,772,774,5,62,0,0,773,
        772,1,0,0,0,773,774,1,0,0,0,774,123,1,0,0,0,775,780,3,108,54,0,776,
        777,5,62,0,0,777,779,3,108,54,0,778,776,1,0,0,0,779,782,1,0,0,0,
        780,778,1,0,0,0,780,781,1,0,0,0,781,784,1,0,0,0,782,780,1,0,0,0,
        783,785,5,62,0,0,784,783,1,0,0,0,784,785,1,0,0,0,785,125,1,0,0,0,
        786,791,3,110,55,0,787,788,5,62,0,0,788,790,3,110,55,0,789,787,1,
        0,0,0,790,793,1,0,0,0,791,789,1,0,0,0,791,792,1,0,0,0,792,795,1,
        0,0,0,793,791,1,0,0,0,794,796,5,62,0,0,795,794,1,0,0,0,795,796,1,
        0,0,0,796,127,1,0,0,0,94,129,134,147,178,180,184,190,200,229,240,
        245,257,263,270,277,283,286,289,297,303,306,309,312,315,320,336,
        341,355,363,375,379,387,391,399,402,411,421,429,432,436,440,453,
        467,471,508,510,518,524,530,534,538,546,550,557,562,566,570,578,
        583,587,591,593,601,618,620,626,630,634,638,642,652,654,658,676,
        688,694,700,702,713,718,725,729,736,740,747,751,758,762,769,773,
        780,784,791,795
    ]

class qasm3Parser ( Parser ):

    grammarFileName = "qasm3Parser.g4"

    atn = ATNDeserializer().deserialize(serializedATN())

    decisionsToDFA = [ DFA(ds, i) for i, ds in enumerate(atn.decisionToState) ]

    sharedContextCache = PredictionContextCache()

    literalNames = [ "<INVALID>", "'OPENQASM'", "'include'", "'defcalgrammar'", 
                     "'def'", "'cal'", "'defcal'", "'gate'", "'extern'", 
                     "'box'", "'let'", "'break'", "'continue'", "'if'", 
                     "'else'", "'end'", "'return'", "'for'", "'while'", 
                     "'in'", "<INVALID>", "<INVALID>", "'input'", "'output'", 
                     "'const'", "'readonly'", "'mutable'", "'qreg'", "'qubit'", 
                     "'creg'", "'bool'", "'bit'", "'int'", "'uint'", "'float'", 
                     "'angle'", "'complex'", "'array'", "'void'", "'duration'", 
                     "'stretch'", "'gphase'", "'inv'", "'pow'", "'ctrl'", 
                     "'negctrl'", "'#dim'", "'durationof'", "'delay'", "'reset'", 
                     "'measure'", "'barrier'", "<INVALID>", "'['", "']'", 
                     "'{'", "'}'", "'('", "')'", "':'", "';'", "'.'", "','", 
                     "'='", "'->'", "'+'", "'++'", "'-'", "'*'", "'**'", 
                     "'/'", "'%'", "'|'", "'||'", "'&'", "'&&'", "'^'", 
                     "'@'", "'~'", "'!'", "<INVALID>", "<INVALID>", "<INVALID>", 
                     "<INVALID>", "'im'" ]

    symbolicNames = [ "<INVALID>", "OPENQASM", "INCLUDE", "DEFCALGRAMMAR", 
                      "DEF", "CAL", "DEFCAL", "GATE", "EXTERN", "BOX", "LET", 
                      "BREAK", "CONTINUE", "IF", "ELSE", "END", "RETURN", 
                      "FOR", "WHILE", "IN", "PRAGMA", "AnnotationKeyword", 
                      "INPUT", "OUTPUT", "CONST", "READONLY", "MUTABLE", 
                      "QREG", "QUBIT", "CREG", "BOOL", "BIT", "INT", "UINT", 
                      "FLOAT", "ANGLE", "COMPLEX", "ARRAY", "VOID", "DURATION", 
                      "STRETCH", "GPHASE", "INV", "POW", "CTRL", "NEGCTRL", 
                      "DIM", "DURATIONOF", "DELAY", "RESET", "MEASURE", 
                      "BARRIER", "BooleanLiteral", "LBRACKET", "RBRACKET", 
                      "LBRACE", "RBRACE", "LPAREN", "RPAREN", "COLON", "SEMICOLON", 
                      "DOT", "COMMA", "EQUALS", "ARROW", "PLUS", "DOUBLE_PLUS", 
                      "MINUS", "ASTERISK", "DOUBLE_ASTERISK", "SLASH", "PERCENT", 
                      "PIPE", "DOUBLE_PIPE", "AMPERSAND", "DOUBLE_AMPERSAND", 
                      "CARET", "AT", "TILDE", "EXCLAMATION_POINT", "EqualityOperator", 
                      "CompoundAssignmentOperator", "ComparisonOperator", 
                      "BitshiftOperator", "IMAG", "ImaginaryLiteral", "BinaryIntegerLiteral", 
                      "OctalIntegerLiteral", "DecimalIntegerLiteral", "HexIntegerLiteral", 
                      "Identifier", "HardwareQubit", "FloatLiteral", "TimingLiteral", 
                      "BitstringLiteral", "StringLiteral", "Whitespace", 
                      "Newline", "LineComment", "BlockComment", "VERSION_IDENTIFER_WHITESPACE", 
                      "VersionSpecifier", "EAT_INITIAL_SPACE", "EAT_LINE_END", 
                      "RemainingLineContent", "CAL_PRELUDE_WHITESPACE", 
                      "CAL_PRELUDE_COMMENT", "DEFCAL_PRELUDE_WHITESPACE", 
                      "DEFCAL_PRELUDE_COMMENT", "CalibrationBlock" ]

    RULE_program = 0
    RULE_version = 1
    RULE_statement = 2
    RULE_annotation = 3
    RULE_scope = 4
    RULE_pragma = 5
    RULE_statementOrScope = 6
    RULE_calibrationGrammarStatement = 7
    RULE_includeStatement = 8
    RULE_breakStatement = 9
    RULE_continueStatement = 10
    RULE_endStatement = 11
    RULE_forStatement = 12
    RULE_ifStatement = 13
    RULE_returnStatement = 14
    RULE_whileStatement = 15
    RULE_barrierStatement = 16
    RULE_boxStatement = 17
    RULE_delayStatement = 18
    RULE_gateCallStatement = 19
    RULE_measureArrowAssignmentStatement = 20
    RULE_resetStatement = 21
    RULE_aliasDeclarationStatement = 22
    RULE_classicalDeclarationStatement = 23
    RULE_constDeclarationStatement = 24
    RULE_ioDeclarationStatement = 25
    RULE_oldStyleDeclarationStatement = 26
    RULE_quantumDeclarationStatement = 27
    RULE_defStatement = 28
    RULE_externStatement = 29
    RULE_gateStatement = 30
    RULE_assignmentStatement = 31
    RULE_expressionStatement = 32
    RULE_calStatement = 33
    RULE_defcalStatement = 34
    RULE_expression = 35
    RULE_aliasExpression = 36
    RULE_declarationExpression = 37
    RULE_measureExpression = 38
    RULE_rangeExpression = 39
    RULE_setExpression = 40
    RULE_arrayLiteral = 41
    RULE_indexOperator = 42
    RULE_indexedIdentifier = 43
    RULE_returnSignature = 44
    RULE_gateModifier = 45
    RULE_scalarType = 46
    RULE_qubitType = 47
    RULE_arrayType = 48
    RULE_arrayReferenceType = 49
    RULE_designator = 50
    RULE_defcalTarget = 51
    RULE_defcalArgumentDefinition = 52
    RULE_defcalOperand = 53
    RULE_gateOperand = 54
    RULE_externArgument = 55
    RULE_argumentDefinition = 56
    RULE_argumentDefinitionList = 57
    RULE_defcalArgumentDefinitionList = 58
    RULE_defcalOperandList = 59
    RULE_expressionList = 60
    RULE_identifierList = 61
    RULE_gateOperandList = 62
    RULE_externArgumentList = 63

    ruleNames =  [ "program", "version", "statement", "annotation", "scope", 
                   "pragma", "statementOrScope", "calibrationGrammarStatement", 
                   "includeStatement", "breakStatement", "continueStatement", 
                   "endStatement", "forStatement", "ifStatement", "returnStatement", 
                   "whileStatement", "barrierStatement", "boxStatement", 
                   "delayStatement", "gateCallStatement", "measureArrowAssignmentStatement", 
                   "resetStatement", "aliasDeclarationStatement", "classicalDeclarationStatement", 
                   "constDeclarationStatement", "ioDeclarationStatement", 
                   "oldStyleDeclarationStatement", "quantumDeclarationStatement", 
                   "defStatement", "externStatement", "gateStatement", "assignmentStatement", 
                   "expressionStatement", "calStatement", "defcalStatement", 
                   "expression", "aliasExpression", "declarationExpression", 
                   "measureExpression", "rangeExpression", "setExpression", 
                   "arrayLiteral", "indexOperator", "indexedIdentifier", 
                   "returnSignature", "gateModifier", "scalarType", "qubitType", 
                   "arrayType", "arrayReferenceType", "designator", "defcalTarget", 
                   "defcalArgumentDefinition", "defcalOperand", "gateOperand", 
                   "externArgument", "argumentDefinition", "argumentDefinitionList", 
                   "defcalArgumentDefinitionList", "defcalOperandList", 
                   "expressionList", "identifierList", "gateOperandList", 
                   "externArgumentList" ]

    EOF = Token.EOF
    OPENQASM=1
    INCLUDE=2
    DEFCALGRAMMAR=3
    DEF=4
    CAL=5
    DEFCAL=6
    GATE=7
    EXTERN=8
    BOX=9
    LET=10
    BREAK=11
    CONTINUE=12
    IF=13
    ELSE=14
    END=15
    RETURN=16
    FOR=17
    WHILE=18
    IN=19
    PRAGMA=20
    AnnotationKeyword=21
    INPUT=22
    OUTPUT=23
    CONST=24
    READONLY=25
    MUTABLE=26
    QREG=27
    QUBIT=28
    CREG=29
    BOOL=30
    BIT=31
    INT=32
    UINT=33
    FLOAT=34
    ANGLE=35
    COMPLEX=36
    ARRAY=37
    VOID=38
    DURATION=39
    STRETCH=40
    GPHASE=41
    INV=42
    POW=43
    CTRL=44
    NEGCTRL=45
    DIM=46
    DURATIONOF=47
    DELAY=48
    RESET=49
    MEASURE=50
    BARRIER=51
    BooleanLiteral=52
    LBRACKET=53
    RBRACKET=54
    LBRACE=55
    RBRACE=56
    LPAREN=57
    RPAREN=58
    COLON=59
    SEMICOLON=60
    DOT=61
    COMMA=62
    EQUALS=63
    ARROW=64
    PLUS=65
    DOUBLE_PLUS=66
    MINUS=67
    ASTERISK=68
    DOUBLE_ASTERISK=69
    SLASH=70
    PERCENT=71
    PIPE=72
    DOUBLE_PIPE=73
    AMPERSAND=74
    DOUBLE_AMPERSAND=75
    CARET=76
    AT=77
    TILDE=78
    EXCLAMATION_POINT=79
    EqualityOperator=80
    CompoundAssignmentOperator=81
    ComparisonOperator=82
    BitshiftOperator=83
    IMAG=84
    ImaginaryLiteral=85
    BinaryIntegerLiteral=86
    OctalIntegerLiteral=87
    DecimalIntegerLiteral=88
    HexIntegerLiteral=89
    Identifier=90
    HardwareQubit=91
    FloatLiteral=92
    TimingLiteral=93
    BitstringLiteral=94
    StringLiteral=95
    Whitespace=96
    Newline=97
    LineComment=98
    BlockComment=99
    VERSION_IDENTIFER_WHITESPACE=100
    VersionSpecifier=101
    EAT_INITIAL_SPACE=102
    EAT_LINE_END=103
    RemainingLineContent=104
    CAL_PRELUDE_WHITESPACE=105
    CAL_PRELUDE_COMMENT=106
    DEFCAL_PRELUDE_WHITESPACE=107
    DEFCAL_PRELUDE_COMMENT=108
    CalibrationBlock=109

    def __init__(self, input:TokenStream, output:TextIO = sys.stdout):
        super().__init__(input, output)
        self.checkVersion("4.11.1")
        self._interp = ParserATNSimulator(self, self.atn, self.decisionsToDFA, self.sharedContextCache)
        self._predicates = None




    class ProgramContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def EOF(self):
            return self.getToken(qasm3Parser.EOF, 0)

        def version(self):
            return self.getTypedRuleContext(qasm3Parser.VersionContext,0)


        def statement(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.StatementContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.StatementContext,i)


        def getRuleIndex(self):
            return qasm3Parser.RULE_program

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterProgram" ):
                listener.enterProgram(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitProgram" ):
                listener.exitProgram(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitProgram" ):
                return visitor.visitProgram(self)
            else:
                return visitor.visitChildren(self)




    def program(self):

        localctx = qasm3Parser.ProgramContext(self, self._ctx, self.state)
        self.enterRule(localctx, 0, self.RULE_program)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 129
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==1:
                self.state = 128
                self.version()


            self.state = 134
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while ((_la) & ~0x3f) == 0 and ((1 << _la) & 153051743607308284) != 0 or (((_la - 67)) & ~0x3f) == 0 and ((1 << (_la - 67)) & 268179457) != 0:
                self.state = 131
                self.statement()
                self.state = 136
                self._errHandler.sync(self)
                _la = self._input.LA(1)

            self.state = 137
            self.match(qasm3Parser.EOF)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class VersionContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def OPENQASM(self):
            return self.getToken(qasm3Parser.OPENQASM, 0)

        def VersionSpecifier(self):
            return self.getToken(qasm3Parser.VersionSpecifier, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_version

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterVersion" ):
                listener.enterVersion(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitVersion" ):
                listener.exitVersion(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitVersion" ):
                return visitor.visitVersion(self)
            else:
                return visitor.visitChildren(self)




    def version(self):

        localctx = qasm3Parser.VersionContext(self, self._ctx, self.state)
        self.enterRule(localctx, 2, self.RULE_version)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 139
            self.match(qasm3Parser.OPENQASM)
            self.state = 140
            self.match(qasm3Parser.VersionSpecifier)
            self.state = 141
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class StatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def pragma(self):
            return self.getTypedRuleContext(qasm3Parser.PragmaContext,0)


        def aliasDeclarationStatement(self):
            return self.getTypedRuleContext(qasm3Parser.AliasDeclarationStatementContext,0)


        def assignmentStatement(self):
            return self.getTypedRuleContext(qasm3Parser.AssignmentStatementContext,0)


        def barrierStatement(self):
            return self.getTypedRuleContext(qasm3Parser.BarrierStatementContext,0)


        def boxStatement(self):
            return self.getTypedRuleContext(qasm3Parser.BoxStatementContext,0)


        def breakStatement(self):
            return self.getTypedRuleContext(qasm3Parser.BreakStatementContext,0)


        def calStatement(self):
            return self.getTypedRuleContext(qasm3Parser.CalStatementContext,0)


        def calibrationGrammarStatement(self):
            return self.getTypedRuleContext(qasm3Parser.CalibrationGrammarStatementContext,0)


        def classicalDeclarationStatement(self):
            return self.getTypedRuleContext(qasm3Parser.ClassicalDeclarationStatementContext,0)


        def constDeclarationStatement(self):
            return self.getTypedRuleContext(qasm3Parser.ConstDeclarationStatementContext,0)


        def continueStatement(self):
            return self.getTypedRuleContext(qasm3Parser.ContinueStatementContext,0)


        def defStatement(self):
            return self.getTypedRuleContext(qasm3Parser.DefStatementContext,0)


        def defcalStatement(self):
            return self.getTypedRuleContext(qasm3Parser.DefcalStatementContext,0)


        def delayStatement(self):
            return self.getTypedRuleContext(qasm3Parser.DelayStatementContext,0)


        def endStatement(self):
            return self.getTypedRuleContext(qasm3Parser.EndStatementContext,0)


        def expressionStatement(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionStatementContext,0)


        def externStatement(self):
            return self.getTypedRuleContext(qasm3Parser.ExternStatementContext,0)


        def forStatement(self):
            return self.getTypedRuleContext(qasm3Parser.ForStatementContext,0)


        def gateCallStatement(self):
            return self.getTypedRuleContext(qasm3Parser.GateCallStatementContext,0)


        def gateStatement(self):
            return self.getTypedRuleContext(qasm3Parser.GateStatementContext,0)


        def ifStatement(self):
            return self.getTypedRuleContext(qasm3Parser.IfStatementContext,0)


        def includeStatement(self):
            return self.getTypedRuleContext(qasm3Parser.IncludeStatementContext,0)


        def ioDeclarationStatement(self):
            return self.getTypedRuleContext(qasm3Parser.IoDeclarationStatementContext,0)


        def measureArrowAssignmentStatement(self):
            return self.getTypedRuleContext(qasm3Parser.MeasureArrowAssignmentStatementContext,0)


        def oldStyleDeclarationStatement(self):
            return self.getTypedRuleContext(qasm3Parser.OldStyleDeclarationStatementContext,0)


        def quantumDeclarationStatement(self):
            return self.getTypedRuleContext(qasm3Parser.QuantumDeclarationStatementContext,0)


        def resetStatement(self):
            return self.getTypedRuleContext(qasm3Parser.ResetStatementContext,0)


        def returnStatement(self):
            return self.getTypedRuleContext(qasm3Parser.ReturnStatementContext,0)


        def whileStatement(self):
            return self.getTypedRuleContext(qasm3Parser.WhileStatementContext,0)


        def annotation(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.AnnotationContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.AnnotationContext,i)


        def getRuleIndex(self):
            return qasm3Parser.RULE_statement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterStatement" ):
                listener.enterStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitStatement" ):
                listener.exitStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitStatement" ):
                return visitor.visitStatement(self)
            else:
                return visitor.visitChildren(self)




    def statement(self):

        localctx = qasm3Parser.StatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 4, self.RULE_statement)
        self._la = 0 # Token type
        try:
            self.state = 180
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [20]:
                self.enterOuterAlt(localctx, 1)
                self.state = 143
                self.pragma()
                pass
            elif token in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 21, 22, 23, 24, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 41, 42, 43, 44, 45, 47, 48, 49, 50, 51, 52, 57, 67, 78, 79, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94]:
                self.enterOuterAlt(localctx, 2)
                self.state = 147
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                while _la==21:
                    self.state = 144
                    self.annotation()
                    self.state = 149
                    self._errHandler.sync(self)
                    _la = self._input.LA(1)

                self.state = 178
                self._errHandler.sync(self)
                la_ = self._interp.adaptivePredict(self._input,3,self._ctx)
                if la_ == 1:
                    self.state = 150
                    self.aliasDeclarationStatement()
                    pass

                elif la_ == 2:
                    self.state = 151
                    self.assignmentStatement()
                    pass

                elif la_ == 3:
                    self.state = 152
                    self.barrierStatement()
                    pass

                elif la_ == 4:
                    self.state = 153
                    self.boxStatement()
                    pass

                elif la_ == 5:
                    self.state = 154
                    self.breakStatement()
                    pass

                elif la_ == 6:
                    self.state = 155
                    self.calStatement()
                    pass

                elif la_ == 7:
                    self.state = 156
                    self.calibrationGrammarStatement()
                    pass

                elif la_ == 8:
                    self.state = 157
                    self.classicalDeclarationStatement()
                    pass

                elif la_ == 9:
                    self.state = 158
                    self.constDeclarationStatement()
                    pass

                elif la_ == 10:
                    self.state = 159
                    self.continueStatement()
                    pass

                elif la_ == 11:
                    self.state = 160
                    self.defStatement()
                    pass

                elif la_ == 12:
                    self.state = 161
                    self.defcalStatement()
                    pass

                elif la_ == 13:
                    self.state = 162
                    self.delayStatement()
                    pass

                elif la_ == 14:
                    self.state = 163
                    self.endStatement()
                    pass

                elif la_ == 15:
                    self.state = 164
                    self.expressionStatement()
                    pass

                elif la_ == 16:
                    self.state = 165
                    self.externStatement()
                    pass

                elif la_ == 17:
                    self.state = 166
                    self.forStatement()
                    pass

                elif la_ == 18:
                    self.state = 167
                    self.gateCallStatement()
                    pass

                elif la_ == 19:
                    self.state = 168
                    self.gateStatement()
                    pass

                elif la_ == 20:
                    self.state = 169
                    self.ifStatement()
                    pass

                elif la_ == 21:
                    self.state = 170
                    self.includeStatement()
                    pass

                elif la_ == 22:
                    self.state = 171
                    self.ioDeclarationStatement()
                    pass

                elif la_ == 23:
                    self.state = 172
                    self.measureArrowAssignmentStatement()
                    pass

                elif la_ == 24:
                    self.state = 173
                    self.oldStyleDeclarationStatement()
                    pass

                elif la_ == 25:
                    self.state = 174
                    self.quantumDeclarationStatement()
                    pass

                elif la_ == 26:
                    self.state = 175
                    self.resetStatement()
                    pass

                elif la_ == 27:
                    self.state = 176
                    self.returnStatement()
                    pass

                elif la_ == 28:
                    self.state = 177
                    self.whileStatement()
                    pass


                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class AnnotationContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def AnnotationKeyword(self):
            return self.getToken(qasm3Parser.AnnotationKeyword, 0)

        def RemainingLineContent(self):
            return self.getToken(qasm3Parser.RemainingLineContent, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_annotation

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterAnnotation" ):
                listener.enterAnnotation(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitAnnotation" ):
                listener.exitAnnotation(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitAnnotation" ):
                return visitor.visitAnnotation(self)
            else:
                return visitor.visitChildren(self)




    def annotation(self):

        localctx = qasm3Parser.AnnotationContext(self, self._ctx, self.state)
        self.enterRule(localctx, 6, self.RULE_annotation)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 182
            self.match(qasm3Parser.AnnotationKeyword)
            self.state = 184
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==104:
                self.state = 183
                self.match(qasm3Parser.RemainingLineContent)


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ScopeContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def LBRACE(self):
            return self.getToken(qasm3Parser.LBRACE, 0)

        def RBRACE(self):
            return self.getToken(qasm3Parser.RBRACE, 0)

        def statement(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.StatementContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.StatementContext,i)


        def getRuleIndex(self):
            return qasm3Parser.RULE_scope

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterScope" ):
                listener.enterScope(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitScope" ):
                listener.exitScope(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitScope" ):
                return visitor.visitScope(self)
            else:
                return visitor.visitChildren(self)




    def scope(self):

        localctx = qasm3Parser.ScopeContext(self, self._ctx, self.state)
        self.enterRule(localctx, 8, self.RULE_scope)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 186
            self.match(qasm3Parser.LBRACE)
            self.state = 190
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while ((_la) & ~0x3f) == 0 and ((1 << _la) & 153051743607308284) != 0 or (((_la - 67)) & ~0x3f) == 0 and ((1 << (_la - 67)) & 268179457) != 0:
                self.state = 187
                self.statement()
                self.state = 192
                self._errHandler.sync(self)
                _la = self._input.LA(1)

            self.state = 193
            self.match(qasm3Parser.RBRACE)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class PragmaContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def PRAGMA(self):
            return self.getToken(qasm3Parser.PRAGMA, 0)

        def RemainingLineContent(self):
            return self.getToken(qasm3Parser.RemainingLineContent, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_pragma

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterPragma" ):
                listener.enterPragma(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitPragma" ):
                listener.exitPragma(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitPragma" ):
                return visitor.visitPragma(self)
            else:
                return visitor.visitChildren(self)




    def pragma(self):

        localctx = qasm3Parser.PragmaContext(self, self._ctx, self.state)
        self.enterRule(localctx, 10, self.RULE_pragma)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 195
            self.match(qasm3Parser.PRAGMA)
            self.state = 196
            self.match(qasm3Parser.RemainingLineContent)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class StatementOrScopeContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def statement(self):
            return self.getTypedRuleContext(qasm3Parser.StatementContext,0)


        def scope(self):
            return self.getTypedRuleContext(qasm3Parser.ScopeContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_statementOrScope

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterStatementOrScope" ):
                listener.enterStatementOrScope(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitStatementOrScope" ):
                listener.exitStatementOrScope(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitStatementOrScope" ):
                return visitor.visitStatementOrScope(self)
            else:
                return visitor.visitChildren(self)




    def statementOrScope(self):

        localctx = qasm3Parser.StatementOrScopeContext(self, self._ctx, self.state)
        self.enterRule(localctx, 12, self.RULE_statementOrScope)
        try:
            self.state = 200
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 20, 21, 22, 23, 24, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 41, 42, 43, 44, 45, 47, 48, 49, 50, 51, 52, 57, 67, 78, 79, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94]:
                self.enterOuterAlt(localctx, 1)
                self.state = 198
                self.statement()
                pass
            elif token in [55]:
                self.enterOuterAlt(localctx, 2)
                self.state = 199
                self.scope()
                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class CalibrationGrammarStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def DEFCALGRAMMAR(self):
            return self.getToken(qasm3Parser.DEFCALGRAMMAR, 0)

        def StringLiteral(self):
            return self.getToken(qasm3Parser.StringLiteral, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_calibrationGrammarStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterCalibrationGrammarStatement" ):
                listener.enterCalibrationGrammarStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitCalibrationGrammarStatement" ):
                listener.exitCalibrationGrammarStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitCalibrationGrammarStatement" ):
                return visitor.visitCalibrationGrammarStatement(self)
            else:
                return visitor.visitChildren(self)




    def calibrationGrammarStatement(self):

        localctx = qasm3Parser.CalibrationGrammarStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 14, self.RULE_calibrationGrammarStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 202
            self.match(qasm3Parser.DEFCALGRAMMAR)
            self.state = 203
            self.match(qasm3Parser.StringLiteral)
            self.state = 204
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class IncludeStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def INCLUDE(self):
            return self.getToken(qasm3Parser.INCLUDE, 0)

        def StringLiteral(self):
            return self.getToken(qasm3Parser.StringLiteral, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_includeStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterIncludeStatement" ):
                listener.enterIncludeStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitIncludeStatement" ):
                listener.exitIncludeStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitIncludeStatement" ):
                return visitor.visitIncludeStatement(self)
            else:
                return visitor.visitChildren(self)




    def includeStatement(self):

        localctx = qasm3Parser.IncludeStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 16, self.RULE_includeStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 206
            self.match(qasm3Parser.INCLUDE)
            self.state = 207
            self.match(qasm3Parser.StringLiteral)
            self.state = 208
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class BreakStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def BREAK(self):
            return self.getToken(qasm3Parser.BREAK, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_breakStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterBreakStatement" ):
                listener.enterBreakStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitBreakStatement" ):
                listener.exitBreakStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitBreakStatement" ):
                return visitor.visitBreakStatement(self)
            else:
                return visitor.visitChildren(self)




    def breakStatement(self):

        localctx = qasm3Parser.BreakStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 18, self.RULE_breakStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 210
            self.match(qasm3Parser.BREAK)
            self.state = 211
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ContinueStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def CONTINUE(self):
            return self.getToken(qasm3Parser.CONTINUE, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_continueStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterContinueStatement" ):
                listener.enterContinueStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitContinueStatement" ):
                listener.exitContinueStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitContinueStatement" ):
                return visitor.visitContinueStatement(self)
            else:
                return visitor.visitChildren(self)




    def continueStatement(self):

        localctx = qasm3Parser.ContinueStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 20, self.RULE_continueStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 213
            self.match(qasm3Parser.CONTINUE)
            self.state = 214
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class EndStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def END(self):
            return self.getToken(qasm3Parser.END, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_endStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterEndStatement" ):
                listener.enterEndStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitEndStatement" ):
                listener.exitEndStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitEndStatement" ):
                return visitor.visitEndStatement(self)
            else:
                return visitor.visitChildren(self)




    def endStatement(self):

        localctx = qasm3Parser.EndStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 22, self.RULE_endStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 216
            self.match(qasm3Parser.END)
            self.state = 217
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ForStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser
            self.body = None # StatementOrScopeContext

        def FOR(self):
            return self.getToken(qasm3Parser.FOR, 0)

        def scalarType(self):
            return self.getTypedRuleContext(qasm3Parser.ScalarTypeContext,0)


        def Identifier(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.Identifier)
            else:
                return self.getToken(qasm3Parser.Identifier, i)

        def IN(self):
            return self.getToken(qasm3Parser.IN, 0)

        def statementOrScope(self):
            return self.getTypedRuleContext(qasm3Parser.StatementOrScopeContext,0)


        def setExpression(self):
            return self.getTypedRuleContext(qasm3Parser.SetExpressionContext,0)


        def LBRACKET(self):
            return self.getToken(qasm3Parser.LBRACKET, 0)

        def rangeExpression(self):
            return self.getTypedRuleContext(qasm3Parser.RangeExpressionContext,0)


        def RBRACKET(self):
            return self.getToken(qasm3Parser.RBRACKET, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_forStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterForStatement" ):
                listener.enterForStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitForStatement" ):
                listener.exitForStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitForStatement" ):
                return visitor.visitForStatement(self)
            else:
                return visitor.visitChildren(self)




    def forStatement(self):

        localctx = qasm3Parser.ForStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 24, self.RULE_forStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 219
            self.match(qasm3Parser.FOR)
            self.state = 220
            self.scalarType()
            self.state = 221
            self.match(qasm3Parser.Identifier)
            self.state = 222
            self.match(qasm3Parser.IN)
            self.state = 229
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [55]:
                self.state = 223
                self.setExpression()
                pass
            elif token in [53]:
                self.state = 224
                self.match(qasm3Parser.LBRACKET)
                self.state = 225
                self.rangeExpression()
                self.state = 226
                self.match(qasm3Parser.RBRACKET)
                pass
            elif token in [90]:
                self.state = 228
                self.match(qasm3Parser.Identifier)
                pass
            else:
                raise NoViableAltException(self)

            self.state = 231
            localctx.body = self.statementOrScope()
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class IfStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser
            self.if_body = None # StatementOrScopeContext
            self.else_body = None # StatementOrScopeContext

        def IF(self):
            return self.getToken(qasm3Parser.IF, 0)

        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)

        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)


        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)

        def statementOrScope(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.StatementOrScopeContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.StatementOrScopeContext,i)


        def ELSE(self):
            return self.getToken(qasm3Parser.ELSE, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_ifStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterIfStatement" ):
                listener.enterIfStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitIfStatement" ):
                listener.exitIfStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitIfStatement" ):
                return visitor.visitIfStatement(self)
            else:
                return visitor.visitChildren(self)




    def ifStatement(self):

        localctx = qasm3Parser.IfStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 26, self.RULE_ifStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 233
            self.match(qasm3Parser.IF)
            self.state = 234
            self.match(qasm3Parser.LPAREN)
            self.state = 235
            self.expression(0)
            self.state = 236
            self.match(qasm3Parser.RPAREN)
            self.state = 237
            localctx.if_body = self.statementOrScope()
            self.state = 240
            self._errHandler.sync(self)
            la_ = self._interp.adaptivePredict(self._input,9,self._ctx)
            if la_ == 1:
                self.state = 238
                self.match(qasm3Parser.ELSE)
                self.state = 239
                localctx.else_body = self.statementOrScope()


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ReturnStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def RETURN(self):
            return self.getToken(qasm3Parser.RETURN, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)


        def measureExpression(self):
            return self.getTypedRuleContext(qasm3Parser.MeasureExpressionContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_returnStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterReturnStatement" ):
                listener.enterReturnStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitReturnStatement" ):
                listener.exitReturnStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitReturnStatement" ):
                return visitor.visitReturnStatement(self)
            else:
                return visitor.visitChildren(self)




    def returnStatement(self):

        localctx = qasm3Parser.ReturnStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 28, self.RULE_returnStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 242
            self.match(qasm3Parser.RETURN)
            self.state = 245
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 47, 52, 57, 67, 78, 79, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94]:
                self.state = 243
                self.expression(0)
                pass
            elif token in [50]:
                self.state = 244
                self.measureExpression()
                pass
            elif token in [60]:
                pass
            else:
                pass
            self.state = 247
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class WhileStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser
            self.body = None # StatementOrScopeContext

        def WHILE(self):
            return self.getToken(qasm3Parser.WHILE, 0)

        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)

        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)


        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)

        def statementOrScope(self):
            return self.getTypedRuleContext(qasm3Parser.StatementOrScopeContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_whileStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterWhileStatement" ):
                listener.enterWhileStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitWhileStatement" ):
                listener.exitWhileStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitWhileStatement" ):
                return visitor.visitWhileStatement(self)
            else:
                return visitor.visitChildren(self)




    def whileStatement(self):

        localctx = qasm3Parser.WhileStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 30, self.RULE_whileStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 249
            self.match(qasm3Parser.WHILE)
            self.state = 250
            self.match(qasm3Parser.LPAREN)
            self.state = 251
            self.expression(0)
            self.state = 252
            self.match(qasm3Parser.RPAREN)
            self.state = 253
            localctx.body = self.statementOrScope()
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class BarrierStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def BARRIER(self):
            return self.getToken(qasm3Parser.BARRIER, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def gateOperandList(self):
            return self.getTypedRuleContext(qasm3Parser.GateOperandListContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_barrierStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterBarrierStatement" ):
                listener.enterBarrierStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitBarrierStatement" ):
                listener.exitBarrierStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitBarrierStatement" ):
                return visitor.visitBarrierStatement(self)
            else:
                return visitor.visitChildren(self)




    def barrierStatement(self):

        localctx = qasm3Parser.BarrierStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 32, self.RULE_barrierStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 255
            self.match(qasm3Parser.BARRIER)
            self.state = 257
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==90 or _la==91:
                self.state = 256
                self.gateOperandList()


            self.state = 259
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class BoxStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def BOX(self):
            return self.getToken(qasm3Parser.BOX, 0)

        def scope(self):
            return self.getTypedRuleContext(qasm3Parser.ScopeContext,0)


        def designator(self):
            return self.getTypedRuleContext(qasm3Parser.DesignatorContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_boxStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterBoxStatement" ):
                listener.enterBoxStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitBoxStatement" ):
                listener.exitBoxStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitBoxStatement" ):
                return visitor.visitBoxStatement(self)
            else:
                return visitor.visitChildren(self)




    def boxStatement(self):

        localctx = qasm3Parser.BoxStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 34, self.RULE_boxStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 261
            self.match(qasm3Parser.BOX)
            self.state = 263
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==53:
                self.state = 262
                self.designator()


            self.state = 265
            self.scope()
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class DelayStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def DELAY(self):
            return self.getToken(qasm3Parser.DELAY, 0)

        def designator(self):
            return self.getTypedRuleContext(qasm3Parser.DesignatorContext,0)


        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def gateOperandList(self):
            return self.getTypedRuleContext(qasm3Parser.GateOperandListContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_delayStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDelayStatement" ):
                listener.enterDelayStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDelayStatement" ):
                listener.exitDelayStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitDelayStatement" ):
                return visitor.visitDelayStatement(self)
            else:
                return visitor.visitChildren(self)




    def delayStatement(self):

        localctx = qasm3Parser.DelayStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 36, self.RULE_delayStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 267
            self.match(qasm3Parser.DELAY)
            self.state = 268
            self.designator()
            self.state = 270
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==90 or _la==91:
                self.state = 269
                self.gateOperandList()


            self.state = 272
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class GateCallStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def gateOperandList(self):
            return self.getTypedRuleContext(qasm3Parser.GateOperandListContext,0)


        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def gateModifier(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.GateModifierContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.GateModifierContext,i)


        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)

        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)

        def designator(self):
            return self.getTypedRuleContext(qasm3Parser.DesignatorContext,0)


        def expressionList(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionListContext,0)


        def GPHASE(self):
            return self.getToken(qasm3Parser.GPHASE, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_gateCallStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterGateCallStatement" ):
                listener.enterGateCallStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitGateCallStatement" ):
                listener.exitGateCallStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitGateCallStatement" ):
                return visitor.visitGateCallStatement(self)
            else:
                return visitor.visitChildren(self)




    def gateCallStatement(self):

        localctx = qasm3Parser.GateCallStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 38, self.RULE_gateCallStatement)
        self._la = 0 # Token type
        try:
            self.state = 315
            self._errHandler.sync(self)
            la_ = self._interp.adaptivePredict(self._input,23,self._ctx)
            if la_ == 1:
                self.enterOuterAlt(localctx, 1)
                self.state = 277
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                while ((_la) & ~0x3f) == 0 and ((1 << _la) & 65970697666560) != 0:
                    self.state = 274
                    self.gateModifier()
                    self.state = 279
                    self._errHandler.sync(self)
                    _la = self._input.LA(1)

                self.state = 280
                self.match(qasm3Parser.Identifier)
                self.state = 286
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==57:
                    self.state = 281
                    self.match(qasm3Parser.LPAREN)
                    self.state = 283
                    self._errHandler.sync(self)
                    _la = self._input.LA(1)
                    if ((_la) & ~0x3f) == 0 and ((1 << _la) & 148761448263188480) != 0 or (((_la - 67)) & ~0x3f) == 0 and ((1 << (_la - 67)) & 268179457) != 0:
                        self.state = 282
                        self.expressionList()


                    self.state = 285
                    self.match(qasm3Parser.RPAREN)


                self.state = 289
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==53:
                    self.state = 288
                    self.designator()


                self.state = 291
                self.gateOperandList()
                self.state = 292
                self.match(qasm3Parser.SEMICOLON)
                pass

            elif la_ == 2:
                self.enterOuterAlt(localctx, 2)
                self.state = 297
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                while ((_la) & ~0x3f) == 0 and ((1 << _la) & 65970697666560) != 0:
                    self.state = 294
                    self.gateModifier()
                    self.state = 299
                    self._errHandler.sync(self)
                    _la = self._input.LA(1)

                self.state = 300
                self.match(qasm3Parser.GPHASE)
                self.state = 306
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==57:
                    self.state = 301
                    self.match(qasm3Parser.LPAREN)
                    self.state = 303
                    self._errHandler.sync(self)
                    _la = self._input.LA(1)
                    if ((_la) & ~0x3f) == 0 and ((1 << _la) & 148761448263188480) != 0 or (((_la - 67)) & ~0x3f) == 0 and ((1 << (_la - 67)) & 268179457) != 0:
                        self.state = 302
                        self.expressionList()


                    self.state = 305
                    self.match(qasm3Parser.RPAREN)


                self.state = 309
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==53:
                    self.state = 308
                    self.designator()


                self.state = 312
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==90 or _la==91:
                    self.state = 311
                    self.gateOperandList()


                self.state = 314
                self.match(qasm3Parser.SEMICOLON)
                pass


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class MeasureArrowAssignmentStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def measureExpression(self):
            return self.getTypedRuleContext(qasm3Parser.MeasureExpressionContext,0)


        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def ARROW(self):
            return self.getToken(qasm3Parser.ARROW, 0)

        def indexedIdentifier(self):
            return self.getTypedRuleContext(qasm3Parser.IndexedIdentifierContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_measureArrowAssignmentStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterMeasureArrowAssignmentStatement" ):
                listener.enterMeasureArrowAssignmentStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitMeasureArrowAssignmentStatement" ):
                listener.exitMeasureArrowAssignmentStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitMeasureArrowAssignmentStatement" ):
                return visitor.visitMeasureArrowAssignmentStatement(self)
            else:
                return visitor.visitChildren(self)




    def measureArrowAssignmentStatement(self):

        localctx = qasm3Parser.MeasureArrowAssignmentStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 40, self.RULE_measureArrowAssignmentStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 317
            self.measureExpression()
            self.state = 320
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==64:
                self.state = 318
                self.match(qasm3Parser.ARROW)
                self.state = 319
                self.indexedIdentifier()


            self.state = 322
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ResetStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def RESET(self):
            return self.getToken(qasm3Parser.RESET, 0)

        def gateOperand(self):
            return self.getTypedRuleContext(qasm3Parser.GateOperandContext,0)


        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_resetStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterResetStatement" ):
                listener.enterResetStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitResetStatement" ):
                listener.exitResetStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitResetStatement" ):
                return visitor.visitResetStatement(self)
            else:
                return visitor.visitChildren(self)




    def resetStatement(self):

        localctx = qasm3Parser.ResetStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 42, self.RULE_resetStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 324
            self.match(qasm3Parser.RESET)
            self.state = 325
            self.gateOperand()
            self.state = 326
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class AliasDeclarationStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def LET(self):
            return self.getToken(qasm3Parser.LET, 0)

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def EQUALS(self):
            return self.getToken(qasm3Parser.EQUALS, 0)

        def aliasExpression(self):
            return self.getTypedRuleContext(qasm3Parser.AliasExpressionContext,0)


        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_aliasDeclarationStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterAliasDeclarationStatement" ):
                listener.enterAliasDeclarationStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitAliasDeclarationStatement" ):
                listener.exitAliasDeclarationStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitAliasDeclarationStatement" ):
                return visitor.visitAliasDeclarationStatement(self)
            else:
                return visitor.visitChildren(self)




    def aliasDeclarationStatement(self):

        localctx = qasm3Parser.AliasDeclarationStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 44, self.RULE_aliasDeclarationStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 328
            self.match(qasm3Parser.LET)
            self.state = 329
            self.match(qasm3Parser.Identifier)
            self.state = 330
            self.match(qasm3Parser.EQUALS)
            self.state = 331
            self.aliasExpression()
            self.state = 332
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ClassicalDeclarationStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def scalarType(self):
            return self.getTypedRuleContext(qasm3Parser.ScalarTypeContext,0)


        def arrayType(self):
            return self.getTypedRuleContext(qasm3Parser.ArrayTypeContext,0)


        def EQUALS(self):
            return self.getToken(qasm3Parser.EQUALS, 0)

        def declarationExpression(self):
            return self.getTypedRuleContext(qasm3Parser.DeclarationExpressionContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_classicalDeclarationStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterClassicalDeclarationStatement" ):
                listener.enterClassicalDeclarationStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitClassicalDeclarationStatement" ):
                listener.exitClassicalDeclarationStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitClassicalDeclarationStatement" ):
                return visitor.visitClassicalDeclarationStatement(self)
            else:
                return visitor.visitChildren(self)




    def classicalDeclarationStatement(self):

        localctx = qasm3Parser.ClassicalDeclarationStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 46, self.RULE_classicalDeclarationStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 336
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [30, 31, 32, 33, 34, 35, 36, 39, 40]:
                self.state = 334
                self.scalarType()
                pass
            elif token in [37]:
                self.state = 335
                self.arrayType()
                pass
            else:
                raise NoViableAltException(self)

            self.state = 338
            self.match(qasm3Parser.Identifier)
            self.state = 341
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==63:
                self.state = 339
                self.match(qasm3Parser.EQUALS)
                self.state = 340
                self.declarationExpression()


            self.state = 343
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ConstDeclarationStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def CONST(self):
            return self.getToken(qasm3Parser.CONST, 0)

        def scalarType(self):
            return self.getTypedRuleContext(qasm3Parser.ScalarTypeContext,0)


        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def EQUALS(self):
            return self.getToken(qasm3Parser.EQUALS, 0)

        def declarationExpression(self):
            return self.getTypedRuleContext(qasm3Parser.DeclarationExpressionContext,0)


        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_constDeclarationStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterConstDeclarationStatement" ):
                listener.enterConstDeclarationStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitConstDeclarationStatement" ):
                listener.exitConstDeclarationStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitConstDeclarationStatement" ):
                return visitor.visitConstDeclarationStatement(self)
            else:
                return visitor.visitChildren(self)




    def constDeclarationStatement(self):

        localctx = qasm3Parser.ConstDeclarationStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 48, self.RULE_constDeclarationStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 345
            self.match(qasm3Parser.CONST)
            self.state = 346
            self.scalarType()
            self.state = 347
            self.match(qasm3Parser.Identifier)
            self.state = 348
            self.match(qasm3Parser.EQUALS)
            self.state = 349
            self.declarationExpression()
            self.state = 350
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class IoDeclarationStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def INPUT(self):
            return self.getToken(qasm3Parser.INPUT, 0)

        def OUTPUT(self):
            return self.getToken(qasm3Parser.OUTPUT, 0)

        def scalarType(self):
            return self.getTypedRuleContext(qasm3Parser.ScalarTypeContext,0)


        def arrayType(self):
            return self.getTypedRuleContext(qasm3Parser.ArrayTypeContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_ioDeclarationStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterIoDeclarationStatement" ):
                listener.enterIoDeclarationStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitIoDeclarationStatement" ):
                listener.exitIoDeclarationStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitIoDeclarationStatement" ):
                return visitor.visitIoDeclarationStatement(self)
            else:
                return visitor.visitChildren(self)




    def ioDeclarationStatement(self):

        localctx = qasm3Parser.IoDeclarationStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 50, self.RULE_ioDeclarationStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 352
            _la = self._input.LA(1)
            if not(_la==22 or _la==23):
                self._errHandler.recoverInline(self)
            else:
                self._errHandler.reportMatch(self)
                self.consume()
            self.state = 355
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [30, 31, 32, 33, 34, 35, 36, 39, 40]:
                self.state = 353
                self.scalarType()
                pass
            elif token in [37]:
                self.state = 354
                self.arrayType()
                pass
            else:
                raise NoViableAltException(self)

            self.state = 357
            self.match(qasm3Parser.Identifier)
            self.state = 358
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class OldStyleDeclarationStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def CREG(self):
            return self.getToken(qasm3Parser.CREG, 0)

        def QREG(self):
            return self.getToken(qasm3Parser.QREG, 0)

        def designator(self):
            return self.getTypedRuleContext(qasm3Parser.DesignatorContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_oldStyleDeclarationStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterOldStyleDeclarationStatement" ):
                listener.enterOldStyleDeclarationStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitOldStyleDeclarationStatement" ):
                listener.exitOldStyleDeclarationStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitOldStyleDeclarationStatement" ):
                return visitor.visitOldStyleDeclarationStatement(self)
            else:
                return visitor.visitChildren(self)




    def oldStyleDeclarationStatement(self):

        localctx = qasm3Parser.OldStyleDeclarationStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 52, self.RULE_oldStyleDeclarationStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 360
            _la = self._input.LA(1)
            if not(_la==27 or _la==29):
                self._errHandler.recoverInline(self)
            else:
                self._errHandler.reportMatch(self)
                self.consume()
            self.state = 361
            self.match(qasm3Parser.Identifier)
            self.state = 363
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==53:
                self.state = 362
                self.designator()


            self.state = 365
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class QuantumDeclarationStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def qubitType(self):
            return self.getTypedRuleContext(qasm3Parser.QubitTypeContext,0)


        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_quantumDeclarationStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterQuantumDeclarationStatement" ):
                listener.enterQuantumDeclarationStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitQuantumDeclarationStatement" ):
                listener.exitQuantumDeclarationStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitQuantumDeclarationStatement" ):
                return visitor.visitQuantumDeclarationStatement(self)
            else:
                return visitor.visitChildren(self)




    def quantumDeclarationStatement(self):

        localctx = qasm3Parser.QuantumDeclarationStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 54, self.RULE_quantumDeclarationStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 367
            self.qubitType()
            self.state = 368
            self.match(qasm3Parser.Identifier)
            self.state = 369
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class DefStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def DEF(self):
            return self.getToken(qasm3Parser.DEF, 0)

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)

        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)

        def scope(self):
            return self.getTypedRuleContext(qasm3Parser.ScopeContext,0)


        def argumentDefinitionList(self):
            return self.getTypedRuleContext(qasm3Parser.ArgumentDefinitionListContext,0)


        def returnSignature(self):
            return self.getTypedRuleContext(qasm3Parser.ReturnSignatureContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_defStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDefStatement" ):
                listener.enterDefStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDefStatement" ):
                listener.exitDefStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitDefStatement" ):
                return visitor.visitDefStatement(self)
            else:
                return visitor.visitChildren(self)




    def defStatement(self):

        localctx = qasm3Parser.DefStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 56, self.RULE_defStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 371
            self.match(qasm3Parser.DEF)
            self.state = 372
            self.match(qasm3Parser.Identifier)
            self.state = 373
            self.match(qasm3Parser.LPAREN)
            self.state = 375
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if ((_la) & ~0x3f) == 0 and ((1 << _la) & 1786672840704) != 0:
                self.state = 374
                self.argumentDefinitionList()


            self.state = 377
            self.match(qasm3Parser.RPAREN)
            self.state = 379
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==64:
                self.state = 378
                self.returnSignature()


            self.state = 381
            self.scope()
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ExternStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def EXTERN(self):
            return self.getToken(qasm3Parser.EXTERN, 0)

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)

        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)

        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def externArgumentList(self):
            return self.getTypedRuleContext(qasm3Parser.ExternArgumentListContext,0)


        def returnSignature(self):
            return self.getTypedRuleContext(qasm3Parser.ReturnSignatureContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_externStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterExternStatement" ):
                listener.enterExternStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitExternStatement" ):
                listener.exitExternStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitExternStatement" ):
                return visitor.visitExternStatement(self)
            else:
                return visitor.visitChildren(self)




    def externStatement(self):

        localctx = qasm3Parser.ExternStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 58, self.RULE_externStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 383
            self.match(qasm3Parser.EXTERN)
            self.state = 384
            self.match(qasm3Parser.Identifier)
            self.state = 385
            self.match(qasm3Parser.LPAREN)
            self.state = 387
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if ((_la) & ~0x3f) == 0 and ((1 << _la) & 1786270187520) != 0:
                self.state = 386
                self.externArgumentList()


            self.state = 389
            self.match(qasm3Parser.RPAREN)
            self.state = 391
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==64:
                self.state = 390
                self.returnSignature()


            self.state = 393
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class GateStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser
            self.params = None # IdentifierListContext
            self.qubits = None # IdentifierListContext

        def GATE(self):
            return self.getToken(qasm3Parser.GATE, 0)

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def scope(self):
            return self.getTypedRuleContext(qasm3Parser.ScopeContext,0)


        def identifierList(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.IdentifierListContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.IdentifierListContext,i)


        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)

        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_gateStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterGateStatement" ):
                listener.enterGateStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitGateStatement" ):
                listener.exitGateStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitGateStatement" ):
                return visitor.visitGateStatement(self)
            else:
                return visitor.visitChildren(self)




    def gateStatement(self):

        localctx = qasm3Parser.GateStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 60, self.RULE_gateStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 395
            self.match(qasm3Parser.GATE)
            self.state = 396
            self.match(qasm3Parser.Identifier)
            self.state = 402
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==57:
                self.state = 397
                self.match(qasm3Parser.LPAREN)
                self.state = 399
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==90:
                    self.state = 398
                    localctx.params = self.identifierList()


                self.state = 401
                self.match(qasm3Parser.RPAREN)


            self.state = 404
            localctx.qubits = self.identifierList()
            self.state = 405
            self.scope()
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class AssignmentStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser
            self.op = None # Token

        def indexedIdentifier(self):
            return self.getTypedRuleContext(qasm3Parser.IndexedIdentifierContext,0)


        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def EQUALS(self):
            return self.getToken(qasm3Parser.EQUALS, 0)

        def CompoundAssignmentOperator(self):
            return self.getToken(qasm3Parser.CompoundAssignmentOperator, 0)

        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)


        def measureExpression(self):
            return self.getTypedRuleContext(qasm3Parser.MeasureExpressionContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_assignmentStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterAssignmentStatement" ):
                listener.enterAssignmentStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitAssignmentStatement" ):
                listener.exitAssignmentStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitAssignmentStatement" ):
                return visitor.visitAssignmentStatement(self)
            else:
                return visitor.visitChildren(self)




    def assignmentStatement(self):

        localctx = qasm3Parser.AssignmentStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 62, self.RULE_assignmentStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 407
            self.indexedIdentifier()
            self.state = 408
            localctx.op = self._input.LT(1)
            _la = self._input.LA(1)
            if not(_la==63 or _la==81):
                localctx.op = self._errHandler.recoverInline(self)
            else:
                self._errHandler.reportMatch(self)
                self.consume()
            self.state = 411
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 47, 52, 57, 67, 78, 79, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94]:
                self.state = 409
                self.expression(0)
                pass
            elif token in [50]:
                self.state = 410
                self.measureExpression()
                pass
            else:
                raise NoViableAltException(self)

            self.state = 413
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ExpressionStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)


        def SEMICOLON(self):
            return self.getToken(qasm3Parser.SEMICOLON, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_expressionStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterExpressionStatement" ):
                listener.enterExpressionStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitExpressionStatement" ):
                listener.exitExpressionStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitExpressionStatement" ):
                return visitor.visitExpressionStatement(self)
            else:
                return visitor.visitChildren(self)




    def expressionStatement(self):

        localctx = qasm3Parser.ExpressionStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 64, self.RULE_expressionStatement)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 415
            self.expression(0)
            self.state = 416
            self.match(qasm3Parser.SEMICOLON)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class CalStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def CAL(self):
            return self.getToken(qasm3Parser.CAL, 0)

        def LBRACE(self):
            return self.getToken(qasm3Parser.LBRACE, 0)

        def RBRACE(self):
            return self.getToken(qasm3Parser.RBRACE, 0)

        def CalibrationBlock(self):
            return self.getToken(qasm3Parser.CalibrationBlock, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_calStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterCalStatement" ):
                listener.enterCalStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitCalStatement" ):
                listener.exitCalStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitCalStatement" ):
                return visitor.visitCalStatement(self)
            else:
                return visitor.visitChildren(self)




    def calStatement(self):

        localctx = qasm3Parser.CalStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 66, self.RULE_calStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 418
            self.match(qasm3Parser.CAL)
            self.state = 419
            self.match(qasm3Parser.LBRACE)
            self.state = 421
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==109:
                self.state = 420
                self.match(qasm3Parser.CalibrationBlock)


            self.state = 423
            self.match(qasm3Parser.RBRACE)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class DefcalStatementContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def DEFCAL(self):
            return self.getToken(qasm3Parser.DEFCAL, 0)

        def defcalTarget(self):
            return self.getTypedRuleContext(qasm3Parser.DefcalTargetContext,0)


        def defcalOperandList(self):
            return self.getTypedRuleContext(qasm3Parser.DefcalOperandListContext,0)


        def LBRACE(self):
            return self.getToken(qasm3Parser.LBRACE, 0)

        def RBRACE(self):
            return self.getToken(qasm3Parser.RBRACE, 0)

        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)

        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)

        def returnSignature(self):
            return self.getTypedRuleContext(qasm3Parser.ReturnSignatureContext,0)


        def CalibrationBlock(self):
            return self.getToken(qasm3Parser.CalibrationBlock, 0)

        def defcalArgumentDefinitionList(self):
            return self.getTypedRuleContext(qasm3Parser.DefcalArgumentDefinitionListContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_defcalStatement

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDefcalStatement" ):
                listener.enterDefcalStatement(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDefcalStatement" ):
                listener.exitDefcalStatement(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitDefcalStatement" ):
                return visitor.visitDefcalStatement(self)
            else:
                return visitor.visitChildren(self)




    def defcalStatement(self):

        localctx = qasm3Parser.DefcalStatementContext(self, self._ctx, self.state)
        self.enterRule(localctx, 68, self.RULE_defcalStatement)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 425
            self.match(qasm3Parser.DEFCAL)
            self.state = 426
            self.defcalTarget()
            self.state = 432
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==57:
                self.state = 427
                self.match(qasm3Parser.LPAREN)
                self.state = 429
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if ((_la) & ~0x3f) == 0 and ((1 << _la) & 148761449303375872) != 0 or (((_la - 67)) & ~0x3f) == 0 and ((1 << (_la - 67)) & 268179457) != 0:
                    self.state = 428
                    self.defcalArgumentDefinitionList()


                self.state = 431
                self.match(qasm3Parser.RPAREN)


            self.state = 434
            self.defcalOperandList()
            self.state = 436
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==64:
                self.state = 435
                self.returnSignature()


            self.state = 438
            self.match(qasm3Parser.LBRACE)
            self.state = 440
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==109:
                self.state = 439
                self.match(qasm3Parser.CalibrationBlock)


            self.state = 442
            self.match(qasm3Parser.RBRACE)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ExpressionContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser


        def getRuleIndex(self):
            return qasm3Parser.RULE_expression

     
        def copyFrom(self, ctx:ParserRuleContext):
            super().copyFrom(ctx)


    class BitwiseXorExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)

        def CARET(self):
            return self.getToken(qasm3Parser.CARET, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterBitwiseXorExpression" ):
                listener.enterBitwiseXorExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitBitwiseXorExpression" ):
                listener.exitBitwiseXorExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitBitwiseXorExpression" ):
                return visitor.visitBitwiseXorExpression(self)
            else:
                return visitor.visitChildren(self)


    class AdditiveExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)

        def PLUS(self):
            return self.getToken(qasm3Parser.PLUS, 0)
        def MINUS(self):
            return self.getToken(qasm3Parser.MINUS, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterAdditiveExpression" ):
                listener.enterAdditiveExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitAdditiveExpression" ):
                listener.exitAdditiveExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitAdditiveExpression" ):
                return visitor.visitAdditiveExpression(self)
            else:
                return visitor.visitChildren(self)


    class DurationofExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def DURATIONOF(self):
            return self.getToken(qasm3Parser.DURATIONOF, 0)
        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)
        def scope(self):
            return self.getTypedRuleContext(qasm3Parser.ScopeContext,0)

        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDurationofExpression" ):
                listener.enterDurationofExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDurationofExpression" ):
                listener.exitDurationofExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitDurationofExpression" ):
                return visitor.visitDurationofExpression(self)
            else:
                return visitor.visitChildren(self)


    class ParenthesisExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)
        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)

        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterParenthesisExpression" ):
                listener.enterParenthesisExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitParenthesisExpression" ):
                listener.exitParenthesisExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitParenthesisExpression" ):
                return visitor.visitParenthesisExpression(self)
            else:
                return visitor.visitChildren(self)


    class ComparisonExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)

        def ComparisonOperator(self):
            return self.getToken(qasm3Parser.ComparisonOperator, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterComparisonExpression" ):
                listener.enterComparisonExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitComparisonExpression" ):
                listener.exitComparisonExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitComparisonExpression" ):
                return visitor.visitComparisonExpression(self)
            else:
                return visitor.visitChildren(self)


    class MultiplicativeExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)

        def ASTERISK(self):
            return self.getToken(qasm3Parser.ASTERISK, 0)
        def SLASH(self):
            return self.getToken(qasm3Parser.SLASH, 0)
        def PERCENT(self):
            return self.getToken(qasm3Parser.PERCENT, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterMultiplicativeExpression" ):
                listener.enterMultiplicativeExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitMultiplicativeExpression" ):
                listener.exitMultiplicativeExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitMultiplicativeExpression" ):
                return visitor.visitMultiplicativeExpression(self)
            else:
                return visitor.visitChildren(self)


    class LogicalOrExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)

        def DOUBLE_PIPE(self):
            return self.getToken(qasm3Parser.DOUBLE_PIPE, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterLogicalOrExpression" ):
                listener.enterLogicalOrExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitLogicalOrExpression" ):
                listener.exitLogicalOrExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitLogicalOrExpression" ):
                return visitor.visitLogicalOrExpression(self)
            else:
                return visitor.visitChildren(self)


    class CastExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)
        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)

        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)
        def scalarType(self):
            return self.getTypedRuleContext(qasm3Parser.ScalarTypeContext,0)

        def arrayType(self):
            return self.getTypedRuleContext(qasm3Parser.ArrayTypeContext,0)


        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterCastExpression" ):
                listener.enterCastExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitCastExpression" ):
                listener.exitCastExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitCastExpression" ):
                return visitor.visitCastExpression(self)
            else:
                return visitor.visitChildren(self)


    class PowerExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)

        def DOUBLE_ASTERISK(self):
            return self.getToken(qasm3Parser.DOUBLE_ASTERISK, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterPowerExpression" ):
                listener.enterPowerExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitPowerExpression" ):
                listener.exitPowerExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitPowerExpression" ):
                return visitor.visitPowerExpression(self)
            else:
                return visitor.visitChildren(self)


    class BitwiseOrExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)

        def PIPE(self):
            return self.getToken(qasm3Parser.PIPE, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterBitwiseOrExpression" ):
                listener.enterBitwiseOrExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitBitwiseOrExpression" ):
                listener.exitBitwiseOrExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitBitwiseOrExpression" ):
                return visitor.visitBitwiseOrExpression(self)
            else:
                return visitor.visitChildren(self)


    class CallExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)
        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)
        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)
        def expressionList(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionListContext,0)


        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterCallExpression" ):
                listener.enterCallExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitCallExpression" ):
                listener.exitCallExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitCallExpression" ):
                return visitor.visitCallExpression(self)
            else:
                return visitor.visitChildren(self)


    class BitshiftExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)

        def BitshiftOperator(self):
            return self.getToken(qasm3Parser.BitshiftOperator, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterBitshiftExpression" ):
                listener.enterBitshiftExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitBitshiftExpression" ):
                listener.exitBitshiftExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitBitshiftExpression" ):
                return visitor.visitBitshiftExpression(self)
            else:
                return visitor.visitChildren(self)


    class BitwiseAndExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)

        def AMPERSAND(self):
            return self.getToken(qasm3Parser.AMPERSAND, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterBitwiseAndExpression" ):
                listener.enterBitwiseAndExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitBitwiseAndExpression" ):
                listener.exitBitwiseAndExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitBitwiseAndExpression" ):
                return visitor.visitBitwiseAndExpression(self)
            else:
                return visitor.visitChildren(self)


    class EqualityExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)

        def EqualityOperator(self):
            return self.getToken(qasm3Parser.EqualityOperator, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterEqualityExpression" ):
                listener.enterEqualityExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitEqualityExpression" ):
                listener.exitEqualityExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitEqualityExpression" ):
                return visitor.visitEqualityExpression(self)
            else:
                return visitor.visitChildren(self)


    class LogicalAndExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)

        def DOUBLE_AMPERSAND(self):
            return self.getToken(qasm3Parser.DOUBLE_AMPERSAND, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterLogicalAndExpression" ):
                listener.enterLogicalAndExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitLogicalAndExpression" ):
                listener.exitLogicalAndExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitLogicalAndExpression" ):
                return visitor.visitLogicalAndExpression(self)
            else:
                return visitor.visitChildren(self)


    class IndexExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)

        def indexOperator(self):
            return self.getTypedRuleContext(qasm3Parser.IndexOperatorContext,0)


        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterIndexExpression" ):
                listener.enterIndexExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitIndexExpression" ):
                listener.exitIndexExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitIndexExpression" ):
                return visitor.visitIndexExpression(self)
            else:
                return visitor.visitChildren(self)


    class UnaryExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.op = None # Token
            self.copyFrom(ctx)

        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)

        def TILDE(self):
            return self.getToken(qasm3Parser.TILDE, 0)
        def EXCLAMATION_POINT(self):
            return self.getToken(qasm3Parser.EXCLAMATION_POINT, 0)
        def MINUS(self):
            return self.getToken(qasm3Parser.MINUS, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterUnaryExpression" ):
                listener.enterUnaryExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitUnaryExpression" ):
                listener.exitUnaryExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitUnaryExpression" ):
                return visitor.visitUnaryExpression(self)
            else:
                return visitor.visitChildren(self)


    class LiteralExpressionContext(ExpressionContext):

        def __init__(self, parser, ctx:ParserRuleContext): # actually a qasm3Parser.ExpressionContext
            super().__init__(parser)
            self.copyFrom(ctx)

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)
        def BinaryIntegerLiteral(self):
            return self.getToken(qasm3Parser.BinaryIntegerLiteral, 0)
        def OctalIntegerLiteral(self):
            return self.getToken(qasm3Parser.OctalIntegerLiteral, 0)
        def DecimalIntegerLiteral(self):
            return self.getToken(qasm3Parser.DecimalIntegerLiteral, 0)
        def HexIntegerLiteral(self):
            return self.getToken(qasm3Parser.HexIntegerLiteral, 0)
        def FloatLiteral(self):
            return self.getToken(qasm3Parser.FloatLiteral, 0)
        def ImaginaryLiteral(self):
            return self.getToken(qasm3Parser.ImaginaryLiteral, 0)
        def BooleanLiteral(self):
            return self.getToken(qasm3Parser.BooleanLiteral, 0)
        def BitstringLiteral(self):
            return self.getToken(qasm3Parser.BitstringLiteral, 0)
        def TimingLiteral(self):
            return self.getToken(qasm3Parser.TimingLiteral, 0)
        def HardwareQubit(self):
            return self.getToken(qasm3Parser.HardwareQubit, 0)

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterLiteralExpression" ):
                listener.enterLiteralExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitLiteralExpression" ):
                listener.exitLiteralExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitLiteralExpression" ):
                return visitor.visitLiteralExpression(self)
            else:
                return visitor.visitChildren(self)



    def expression(self, _p:int=0):
        _parentctx = self._ctx
        _parentState = self.state
        localctx = qasm3Parser.ExpressionContext(self, self._ctx, _parentState)
        _prevctx = localctx
        _startState = 70
        self.enterRecursionRule(localctx, 70, self.RULE_expression, _p)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 471
            self._errHandler.sync(self)
            la_ = self._interp.adaptivePredict(self._input,43,self._ctx)
            if la_ == 1:
                localctx = qasm3Parser.ParenthesisExpressionContext(self, localctx)
                self._ctx = localctx
                _prevctx = localctx

                self.state = 445
                self.match(qasm3Parser.LPAREN)
                self.state = 446
                self.expression(0)
                self.state = 447
                self.match(qasm3Parser.RPAREN)
                pass

            elif la_ == 2:
                localctx = qasm3Parser.UnaryExpressionContext(self, localctx)
                self._ctx = localctx
                _prevctx = localctx
                self.state = 449
                localctx.op = self._input.LT(1)
                _la = self._input.LA(1)
                if not((((_la - 67)) & ~0x3f) == 0 and ((1 << (_la - 67)) & 6145) != 0):
                    localctx.op = self._errHandler.recoverInline(self)
                else:
                    self._errHandler.reportMatch(self)
                    self.consume()
                self.state = 450
                self.expression(15)
                pass

            elif la_ == 3:
                localctx = qasm3Parser.CastExpressionContext(self, localctx)
                self._ctx = localctx
                _prevctx = localctx
                self.state = 453
                self._errHandler.sync(self)
                token = self._input.LA(1)
                if token in [30, 31, 32, 33, 34, 35, 36, 39, 40]:
                    self.state = 451
                    self.scalarType()
                    pass
                elif token in [37]:
                    self.state = 452
                    self.arrayType()
                    pass
                else:
                    raise NoViableAltException(self)

                self.state = 455
                self.match(qasm3Parser.LPAREN)
                self.state = 456
                self.expression(0)
                self.state = 457
                self.match(qasm3Parser.RPAREN)
                pass

            elif la_ == 4:
                localctx = qasm3Parser.DurationofExpressionContext(self, localctx)
                self._ctx = localctx
                _prevctx = localctx
                self.state = 459
                self.match(qasm3Parser.DURATIONOF)
                self.state = 460
                self.match(qasm3Parser.LPAREN)
                self.state = 461
                self.scope()
                self.state = 462
                self.match(qasm3Parser.RPAREN)
                pass

            elif la_ == 5:
                localctx = qasm3Parser.CallExpressionContext(self, localctx)
                self._ctx = localctx
                _prevctx = localctx
                self.state = 464
                self.match(qasm3Parser.Identifier)
                self.state = 465
                self.match(qasm3Parser.LPAREN)
                self.state = 467
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if ((_la) & ~0x3f) == 0 and ((1 << _la) & 148761448263188480) != 0 or (((_la - 67)) & ~0x3f) == 0 and ((1 << (_la - 67)) & 268179457) != 0:
                    self.state = 466
                    self.expressionList()


                self.state = 469
                self.match(qasm3Parser.RPAREN)
                pass

            elif la_ == 6:
                localctx = qasm3Parser.LiteralExpressionContext(self, localctx)
                self._ctx = localctx
                _prevctx = localctx
                self.state = 470
                _la = self._input.LA(1)
                if not((((_la - 52)) & ~0x3f) == 0 and ((1 << (_la - 52)) & 8787503087617) != 0):
                    self._errHandler.recoverInline(self)
                else:
                    self._errHandler.reportMatch(self)
                    self.consume()
                pass


            self._ctx.stop = self._input.LT(-1)
            self.state = 510
            self._errHandler.sync(self)
            _alt = self._interp.adaptivePredict(self._input,45,self._ctx)
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt==1:
                    if self._parseListeners is not None:
                        self.triggerExitRuleEvent()
                    _prevctx = localctx
                    self.state = 508
                    self._errHandler.sync(self)
                    la_ = self._interp.adaptivePredict(self._input,44,self._ctx)
                    if la_ == 1:
                        localctx = qasm3Parser.PowerExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 473
                        if not self.precpred(self._ctx, 16):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 16)")
                        self.state = 474
                        localctx.op = self.match(qasm3Parser.DOUBLE_ASTERISK)
                        self.state = 475
                        self.expression(16)
                        pass

                    elif la_ == 2:
                        localctx = qasm3Parser.MultiplicativeExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 476
                        if not self.precpred(self._ctx, 14):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 14)")
                        self.state = 477
                        localctx.op = self._input.LT(1)
                        _la = self._input.LA(1)
                        if not((((_la - 68)) & ~0x3f) == 0 and ((1 << (_la - 68)) & 13) != 0):
                            localctx.op = self._errHandler.recoverInline(self)
                        else:
                            self._errHandler.reportMatch(self)
                            self.consume()
                        self.state = 478
                        self.expression(15)
                        pass

                    elif la_ == 3:
                        localctx = qasm3Parser.AdditiveExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 479
                        if not self.precpred(self._ctx, 13):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 13)")
                        self.state = 480
                        localctx.op = self._input.LT(1)
                        _la = self._input.LA(1)
                        if not(_la==65 or _la==67):
                            localctx.op = self._errHandler.recoverInline(self)
                        else:
                            self._errHandler.reportMatch(self)
                            self.consume()
                        self.state = 481
                        self.expression(14)
                        pass

                    elif la_ == 4:
                        localctx = qasm3Parser.BitshiftExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 482
                        if not self.precpred(self._ctx, 12):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 12)")
                        self.state = 483
                        localctx.op = self.match(qasm3Parser.BitshiftOperator)
                        self.state = 484
                        self.expression(13)
                        pass

                    elif la_ == 5:
                        localctx = qasm3Parser.ComparisonExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 485
                        if not self.precpred(self._ctx, 11):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 11)")
                        self.state = 486
                        localctx.op = self.match(qasm3Parser.ComparisonOperator)
                        self.state = 487
                        self.expression(12)
                        pass

                    elif la_ == 6:
                        localctx = qasm3Parser.EqualityExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 488
                        if not self.precpred(self._ctx, 10):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 10)")
                        self.state = 489
                        localctx.op = self.match(qasm3Parser.EqualityOperator)
                        self.state = 490
                        self.expression(11)
                        pass

                    elif la_ == 7:
                        localctx = qasm3Parser.BitwiseAndExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 491
                        if not self.precpred(self._ctx, 9):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 9)")
                        self.state = 492
                        localctx.op = self.match(qasm3Parser.AMPERSAND)
                        self.state = 493
                        self.expression(10)
                        pass

                    elif la_ == 8:
                        localctx = qasm3Parser.BitwiseXorExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 494
                        if not self.precpred(self._ctx, 8):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 8)")
                        self.state = 495
                        localctx.op = self.match(qasm3Parser.CARET)
                        self.state = 496
                        self.expression(9)
                        pass

                    elif la_ == 9:
                        localctx = qasm3Parser.BitwiseOrExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 497
                        if not self.precpred(self._ctx, 7):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 7)")
                        self.state = 498
                        localctx.op = self.match(qasm3Parser.PIPE)
                        self.state = 499
                        self.expression(8)
                        pass

                    elif la_ == 10:
                        localctx = qasm3Parser.LogicalAndExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 500
                        if not self.precpred(self._ctx, 6):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 6)")
                        self.state = 501
                        localctx.op = self.match(qasm3Parser.DOUBLE_AMPERSAND)
                        self.state = 502
                        self.expression(7)
                        pass

                    elif la_ == 11:
                        localctx = qasm3Parser.LogicalOrExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 503
                        if not self.precpred(self._ctx, 5):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 5)")
                        self.state = 504
                        localctx.op = self.match(qasm3Parser.DOUBLE_PIPE)
                        self.state = 505
                        self.expression(6)
                        pass

                    elif la_ == 12:
                        localctx = qasm3Parser.IndexExpressionContext(self, qasm3Parser.ExpressionContext(self, _parentctx, _parentState))
                        self.pushNewRecursionContext(localctx, _startState, self.RULE_expression)
                        self.state = 506
                        if not self.precpred(self._ctx, 17):
                            from antlr4.error.Errors import FailedPredicateException
                            raise FailedPredicateException(self, "self.precpred(self._ctx, 17)")
                        self.state = 507
                        self.indexOperator()
                        pass

             
                self.state = 512
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,45,self._ctx)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.unrollRecursionContexts(_parentctx)
        return localctx


    class AliasExpressionContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)


        def DOUBLE_PLUS(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.DOUBLE_PLUS)
            else:
                return self.getToken(qasm3Parser.DOUBLE_PLUS, i)

        def getRuleIndex(self):
            return qasm3Parser.RULE_aliasExpression

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterAliasExpression" ):
                listener.enterAliasExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitAliasExpression" ):
                listener.exitAliasExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitAliasExpression" ):
                return visitor.visitAliasExpression(self)
            else:
                return visitor.visitChildren(self)




    def aliasExpression(self):

        localctx = qasm3Parser.AliasExpressionContext(self, self._ctx, self.state)
        self.enterRule(localctx, 72, self.RULE_aliasExpression)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 513
            self.expression(0)
            self.state = 518
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while _la==66:
                self.state = 514
                self.match(qasm3Parser.DOUBLE_PLUS)
                self.state = 515
                self.expression(0)
                self.state = 520
                self._errHandler.sync(self)
                _la = self._input.LA(1)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class DeclarationExpressionContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def arrayLiteral(self):
            return self.getTypedRuleContext(qasm3Parser.ArrayLiteralContext,0)


        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)


        def measureExpression(self):
            return self.getTypedRuleContext(qasm3Parser.MeasureExpressionContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_declarationExpression

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDeclarationExpression" ):
                listener.enterDeclarationExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDeclarationExpression" ):
                listener.exitDeclarationExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitDeclarationExpression" ):
                return visitor.visitDeclarationExpression(self)
            else:
                return visitor.visitChildren(self)




    def declarationExpression(self):

        localctx = qasm3Parser.DeclarationExpressionContext(self, self._ctx, self.state)
        self.enterRule(localctx, 74, self.RULE_declarationExpression)
        try:
            self.state = 524
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [55]:
                self.enterOuterAlt(localctx, 1)
                self.state = 521
                self.arrayLiteral()
                pass
            elif token in [30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 47, 52, 57, 67, 78, 79, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94]:
                self.enterOuterAlt(localctx, 2)
                self.state = 522
                self.expression(0)
                pass
            elif token in [50]:
                self.enterOuterAlt(localctx, 3)
                self.state = 523
                self.measureExpression()
                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class MeasureExpressionContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def MEASURE(self):
            return self.getToken(qasm3Parser.MEASURE, 0)

        def gateOperand(self):
            return self.getTypedRuleContext(qasm3Parser.GateOperandContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_measureExpression

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterMeasureExpression" ):
                listener.enterMeasureExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitMeasureExpression" ):
                listener.exitMeasureExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitMeasureExpression" ):
                return visitor.visitMeasureExpression(self)
            else:
                return visitor.visitChildren(self)




    def measureExpression(self):

        localctx = qasm3Parser.MeasureExpressionContext(self, self._ctx, self.state)
        self.enterRule(localctx, 76, self.RULE_measureExpression)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 526
            self.match(qasm3Parser.MEASURE)
            self.state = 527
            self.gateOperand()
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class RangeExpressionContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def COLON(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.COLON)
            else:
                return self.getToken(qasm3Parser.COLON, i)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)


        def getRuleIndex(self):
            return qasm3Parser.RULE_rangeExpression

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterRangeExpression" ):
                listener.enterRangeExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitRangeExpression" ):
                listener.exitRangeExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitRangeExpression" ):
                return visitor.visitRangeExpression(self)
            else:
                return visitor.visitChildren(self)




    def rangeExpression(self):

        localctx = qasm3Parser.RangeExpressionContext(self, self._ctx, self.state)
        self.enterRule(localctx, 78, self.RULE_rangeExpression)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 530
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if ((_la) & ~0x3f) == 0 and ((1 << _la) & 148761448263188480) != 0 or (((_la - 67)) & ~0x3f) == 0 and ((1 << (_la - 67)) & 268179457) != 0:
                self.state = 529
                self.expression(0)


            self.state = 532
            self.match(qasm3Parser.COLON)
            self.state = 534
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if ((_la) & ~0x3f) == 0 and ((1 << _la) & 148761448263188480) != 0 or (((_la - 67)) & ~0x3f) == 0 and ((1 << (_la - 67)) & 268179457) != 0:
                self.state = 533
                self.expression(0)


            self.state = 538
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==59:
                self.state = 536
                self.match(qasm3Parser.COLON)
                self.state = 537
                self.expression(0)


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class SetExpressionContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def LBRACE(self):
            return self.getToken(qasm3Parser.LBRACE, 0)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)


        def RBRACE(self):
            return self.getToken(qasm3Parser.RBRACE, 0)

        def COMMA(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.COMMA)
            else:
                return self.getToken(qasm3Parser.COMMA, i)

        def getRuleIndex(self):
            return qasm3Parser.RULE_setExpression

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterSetExpression" ):
                listener.enterSetExpression(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitSetExpression" ):
                listener.exitSetExpression(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitSetExpression" ):
                return visitor.visitSetExpression(self)
            else:
                return visitor.visitChildren(self)




    def setExpression(self):

        localctx = qasm3Parser.SetExpressionContext(self, self._ctx, self.state)
        self.enterRule(localctx, 80, self.RULE_setExpression)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 540
            self.match(qasm3Parser.LBRACE)
            self.state = 541
            self.expression(0)
            self.state = 546
            self._errHandler.sync(self)
            _alt = self._interp.adaptivePredict(self._input,51,self._ctx)
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt==1:
                    self.state = 542
                    self.match(qasm3Parser.COMMA)
                    self.state = 543
                    self.expression(0) 
                self.state = 548
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,51,self._ctx)

            self.state = 550
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==62:
                self.state = 549
                self.match(qasm3Parser.COMMA)


            self.state = 552
            self.match(qasm3Parser.RBRACE)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ArrayLiteralContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def LBRACE(self):
            return self.getToken(qasm3Parser.LBRACE, 0)

        def RBRACE(self):
            return self.getToken(qasm3Parser.RBRACE, 0)

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)


        def arrayLiteral(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ArrayLiteralContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ArrayLiteralContext,i)


        def COMMA(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.COMMA)
            else:
                return self.getToken(qasm3Parser.COMMA, i)

        def getRuleIndex(self):
            return qasm3Parser.RULE_arrayLiteral

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterArrayLiteral" ):
                listener.enterArrayLiteral(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitArrayLiteral" ):
                listener.exitArrayLiteral(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitArrayLiteral" ):
                return visitor.visitArrayLiteral(self)
            else:
                return visitor.visitChildren(self)




    def arrayLiteral(self):

        localctx = qasm3Parser.ArrayLiteralContext(self, self._ctx, self.state)
        self.enterRule(localctx, 82, self.RULE_arrayLiteral)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 554
            self.match(qasm3Parser.LBRACE)
            self.state = 557
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 47, 52, 57, 67, 78, 79, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94]:
                self.state = 555
                self.expression(0)
                pass
            elif token in [55]:
                self.state = 556
                self.arrayLiteral()
                pass
            else:
                raise NoViableAltException(self)

            self.state = 566
            self._errHandler.sync(self)
            _alt = self._interp.adaptivePredict(self._input,55,self._ctx)
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt==1:
                    self.state = 559
                    self.match(qasm3Parser.COMMA)
                    self.state = 562
                    self._errHandler.sync(self)
                    token = self._input.LA(1)
                    if token in [30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 47, 52, 57, 67, 78, 79, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94]:
                        self.state = 560
                        self.expression(0)
                        pass
                    elif token in [55]:
                        self.state = 561
                        self.arrayLiteral()
                        pass
                    else:
                        raise NoViableAltException(self)
             
                self.state = 568
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,55,self._ctx)

            self.state = 570
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==62:
                self.state = 569
                self.match(qasm3Parser.COMMA)


            self.state = 572
            self.match(qasm3Parser.RBRACE)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class IndexOperatorContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def LBRACKET(self):
            return self.getToken(qasm3Parser.LBRACKET, 0)

        def RBRACKET(self):
            return self.getToken(qasm3Parser.RBRACKET, 0)

        def setExpression(self):
            return self.getTypedRuleContext(qasm3Parser.SetExpressionContext,0)


        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)


        def rangeExpression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.RangeExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.RangeExpressionContext,i)


        def COMMA(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.COMMA)
            else:
                return self.getToken(qasm3Parser.COMMA, i)

        def getRuleIndex(self):
            return qasm3Parser.RULE_indexOperator

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterIndexOperator" ):
                listener.enterIndexOperator(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitIndexOperator" ):
                listener.exitIndexOperator(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitIndexOperator" ):
                return visitor.visitIndexOperator(self)
            else:
                return visitor.visitChildren(self)




    def indexOperator(self):

        localctx = qasm3Parser.IndexOperatorContext(self, self._ctx, self.state)
        self.enterRule(localctx, 84, self.RULE_indexOperator)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 574
            self.match(qasm3Parser.LBRACKET)
            self.state = 593
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [55]:
                self.state = 575
                self.setExpression()
                pass
            elif token in [30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 47, 52, 57, 59, 67, 78, 79, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94]:
                self.state = 578
                self._errHandler.sync(self)
                la_ = self._interp.adaptivePredict(self._input,57,self._ctx)
                if la_ == 1:
                    self.state = 576
                    self.expression(0)
                    pass

                elif la_ == 2:
                    self.state = 577
                    self.rangeExpression()
                    pass


                self.state = 587
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,59,self._ctx)
                while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                    if _alt==1:
                        self.state = 580
                        self.match(qasm3Parser.COMMA)
                        self.state = 583
                        self._errHandler.sync(self)
                        la_ = self._interp.adaptivePredict(self._input,58,self._ctx)
                        if la_ == 1:
                            self.state = 581
                            self.expression(0)
                            pass

                        elif la_ == 2:
                            self.state = 582
                            self.rangeExpression()
                            pass

                 
                    self.state = 589
                    self._errHandler.sync(self)
                    _alt = self._interp.adaptivePredict(self._input,59,self._ctx)

                self.state = 591
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==62:
                    self.state = 590
                    self.match(qasm3Parser.COMMA)


                pass
            else:
                raise NoViableAltException(self)

            self.state = 595
            self.match(qasm3Parser.RBRACKET)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class IndexedIdentifierContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def indexOperator(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.IndexOperatorContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.IndexOperatorContext,i)


        def getRuleIndex(self):
            return qasm3Parser.RULE_indexedIdentifier

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterIndexedIdentifier" ):
                listener.enterIndexedIdentifier(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitIndexedIdentifier" ):
                listener.exitIndexedIdentifier(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitIndexedIdentifier" ):
                return visitor.visitIndexedIdentifier(self)
            else:
                return visitor.visitChildren(self)




    def indexedIdentifier(self):

        localctx = qasm3Parser.IndexedIdentifierContext(self, self._ctx, self.state)
        self.enterRule(localctx, 86, self.RULE_indexedIdentifier)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 597
            self.match(qasm3Parser.Identifier)
            self.state = 601
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            while _la==53:
                self.state = 598
                self.indexOperator()
                self.state = 603
                self._errHandler.sync(self)
                _la = self._input.LA(1)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ReturnSignatureContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def ARROW(self):
            return self.getToken(qasm3Parser.ARROW, 0)

        def scalarType(self):
            return self.getTypedRuleContext(qasm3Parser.ScalarTypeContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_returnSignature

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterReturnSignature" ):
                listener.enterReturnSignature(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitReturnSignature" ):
                listener.exitReturnSignature(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitReturnSignature" ):
                return visitor.visitReturnSignature(self)
            else:
                return visitor.visitChildren(self)




    def returnSignature(self):

        localctx = qasm3Parser.ReturnSignatureContext(self, self._ctx, self.state)
        self.enterRule(localctx, 88, self.RULE_returnSignature)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 604
            self.match(qasm3Parser.ARROW)
            self.state = 605
            self.scalarType()
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class GateModifierContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def AT(self):
            return self.getToken(qasm3Parser.AT, 0)

        def INV(self):
            return self.getToken(qasm3Parser.INV, 0)

        def POW(self):
            return self.getToken(qasm3Parser.POW, 0)

        def LPAREN(self):
            return self.getToken(qasm3Parser.LPAREN, 0)

        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)


        def RPAREN(self):
            return self.getToken(qasm3Parser.RPAREN, 0)

        def CTRL(self):
            return self.getToken(qasm3Parser.CTRL, 0)

        def NEGCTRL(self):
            return self.getToken(qasm3Parser.NEGCTRL, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_gateModifier

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterGateModifier" ):
                listener.enterGateModifier(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitGateModifier" ):
                listener.exitGateModifier(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitGateModifier" ):
                return visitor.visitGateModifier(self)
            else:
                return visitor.visitChildren(self)




    def gateModifier(self):

        localctx = qasm3Parser.GateModifierContext(self, self._ctx, self.state)
        self.enterRule(localctx, 90, self.RULE_gateModifier)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 620
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [42]:
                self.state = 607
                self.match(qasm3Parser.INV)
                pass
            elif token in [43]:
                self.state = 608
                self.match(qasm3Parser.POW)
                self.state = 609
                self.match(qasm3Parser.LPAREN)
                self.state = 610
                self.expression(0)
                self.state = 611
                self.match(qasm3Parser.RPAREN)
                pass
            elif token in [44, 45]:
                self.state = 613
                _la = self._input.LA(1)
                if not(_la==44 or _la==45):
                    self._errHandler.recoverInline(self)
                else:
                    self._errHandler.reportMatch(self)
                    self.consume()
                self.state = 618
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==57:
                    self.state = 614
                    self.match(qasm3Parser.LPAREN)
                    self.state = 615
                    self.expression(0)
                    self.state = 616
                    self.match(qasm3Parser.RPAREN)


                pass
            else:
                raise NoViableAltException(self)

            self.state = 622
            self.match(qasm3Parser.AT)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ScalarTypeContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def BIT(self):
            return self.getToken(qasm3Parser.BIT, 0)

        def designator(self):
            return self.getTypedRuleContext(qasm3Parser.DesignatorContext,0)


        def INT(self):
            return self.getToken(qasm3Parser.INT, 0)

        def UINT(self):
            return self.getToken(qasm3Parser.UINT, 0)

        def FLOAT(self):
            return self.getToken(qasm3Parser.FLOAT, 0)

        def ANGLE(self):
            return self.getToken(qasm3Parser.ANGLE, 0)

        def BOOL(self):
            return self.getToken(qasm3Parser.BOOL, 0)

        def DURATION(self):
            return self.getToken(qasm3Parser.DURATION, 0)

        def STRETCH(self):
            return self.getToken(qasm3Parser.STRETCH, 0)

        def COMPLEX(self):
            return self.getToken(qasm3Parser.COMPLEX, 0)

        def LBRACKET(self):
            return self.getToken(qasm3Parser.LBRACKET, 0)

        def scalarType(self):
            return self.getTypedRuleContext(qasm3Parser.ScalarTypeContext,0)


        def RBRACKET(self):
            return self.getToken(qasm3Parser.RBRACKET, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_scalarType

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterScalarType" ):
                listener.enterScalarType(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitScalarType" ):
                listener.exitScalarType(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitScalarType" ):
                return visitor.visitScalarType(self)
            else:
                return visitor.visitChildren(self)




    def scalarType(self):

        localctx = qasm3Parser.ScalarTypeContext(self, self._ctx, self.state)
        self.enterRule(localctx, 92, self.RULE_scalarType)
        self._la = 0 # Token type
        try:
            self.state = 654
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [31]:
                self.enterOuterAlt(localctx, 1)
                self.state = 624
                self.match(qasm3Parser.BIT)
                self.state = 626
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==53:
                    self.state = 625
                    self.designator()


                pass
            elif token in [32]:
                self.enterOuterAlt(localctx, 2)
                self.state = 628
                self.match(qasm3Parser.INT)
                self.state = 630
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==53:
                    self.state = 629
                    self.designator()


                pass
            elif token in [33]:
                self.enterOuterAlt(localctx, 3)
                self.state = 632
                self.match(qasm3Parser.UINT)
                self.state = 634
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==53:
                    self.state = 633
                    self.designator()


                pass
            elif token in [34]:
                self.enterOuterAlt(localctx, 4)
                self.state = 636
                self.match(qasm3Parser.FLOAT)
                self.state = 638
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==53:
                    self.state = 637
                    self.designator()


                pass
            elif token in [35]:
                self.enterOuterAlt(localctx, 5)
                self.state = 640
                self.match(qasm3Parser.ANGLE)
                self.state = 642
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==53:
                    self.state = 641
                    self.designator()


                pass
            elif token in [30]:
                self.enterOuterAlt(localctx, 6)
                self.state = 644
                self.match(qasm3Parser.BOOL)
                pass
            elif token in [39]:
                self.enterOuterAlt(localctx, 7)
                self.state = 645
                self.match(qasm3Parser.DURATION)
                pass
            elif token in [40]:
                self.enterOuterAlt(localctx, 8)
                self.state = 646
                self.match(qasm3Parser.STRETCH)
                pass
            elif token in [36]:
                self.enterOuterAlt(localctx, 9)
                self.state = 647
                self.match(qasm3Parser.COMPLEX)
                self.state = 652
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==53:
                    self.state = 648
                    self.match(qasm3Parser.LBRACKET)
                    self.state = 649
                    self.scalarType()
                    self.state = 650
                    self.match(qasm3Parser.RBRACKET)


                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class QubitTypeContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def QUBIT(self):
            return self.getToken(qasm3Parser.QUBIT, 0)

        def designator(self):
            return self.getTypedRuleContext(qasm3Parser.DesignatorContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_qubitType

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterQubitType" ):
                listener.enterQubitType(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitQubitType" ):
                listener.exitQubitType(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitQubitType" ):
                return visitor.visitQubitType(self)
            else:
                return visitor.visitChildren(self)




    def qubitType(self):

        localctx = qasm3Parser.QubitTypeContext(self, self._ctx, self.state)
        self.enterRule(localctx, 94, self.RULE_qubitType)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 656
            self.match(qasm3Parser.QUBIT)
            self.state = 658
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==53:
                self.state = 657
                self.designator()


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ArrayTypeContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def ARRAY(self):
            return self.getToken(qasm3Parser.ARRAY, 0)

        def LBRACKET(self):
            return self.getToken(qasm3Parser.LBRACKET, 0)

        def scalarType(self):
            return self.getTypedRuleContext(qasm3Parser.ScalarTypeContext,0)


        def COMMA(self):
            return self.getToken(qasm3Parser.COMMA, 0)

        def expressionList(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionListContext,0)


        def RBRACKET(self):
            return self.getToken(qasm3Parser.RBRACKET, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_arrayType

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterArrayType" ):
                listener.enterArrayType(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitArrayType" ):
                listener.exitArrayType(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitArrayType" ):
                return visitor.visitArrayType(self)
            else:
                return visitor.visitChildren(self)




    def arrayType(self):

        localctx = qasm3Parser.ArrayTypeContext(self, self._ctx, self.state)
        self.enterRule(localctx, 96, self.RULE_arrayType)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 660
            self.match(qasm3Parser.ARRAY)
            self.state = 661
            self.match(qasm3Parser.LBRACKET)
            self.state = 662
            self.scalarType()
            self.state = 663
            self.match(qasm3Parser.COMMA)
            self.state = 664
            self.expressionList()
            self.state = 665
            self.match(qasm3Parser.RBRACKET)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ArrayReferenceTypeContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def ARRAY(self):
            return self.getToken(qasm3Parser.ARRAY, 0)

        def LBRACKET(self):
            return self.getToken(qasm3Parser.LBRACKET, 0)

        def scalarType(self):
            return self.getTypedRuleContext(qasm3Parser.ScalarTypeContext,0)


        def COMMA(self):
            return self.getToken(qasm3Parser.COMMA, 0)

        def RBRACKET(self):
            return self.getToken(qasm3Parser.RBRACKET, 0)

        def READONLY(self):
            return self.getToken(qasm3Parser.READONLY, 0)

        def MUTABLE(self):
            return self.getToken(qasm3Parser.MUTABLE, 0)

        def expressionList(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionListContext,0)


        def DIM(self):
            return self.getToken(qasm3Parser.DIM, 0)

        def EQUALS(self):
            return self.getToken(qasm3Parser.EQUALS, 0)

        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_arrayReferenceType

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterArrayReferenceType" ):
                listener.enterArrayReferenceType(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitArrayReferenceType" ):
                listener.exitArrayReferenceType(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitArrayReferenceType" ):
                return visitor.visitArrayReferenceType(self)
            else:
                return visitor.visitChildren(self)




    def arrayReferenceType(self):

        localctx = qasm3Parser.ArrayReferenceTypeContext(self, self._ctx, self.state)
        self.enterRule(localctx, 98, self.RULE_arrayReferenceType)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 667
            _la = self._input.LA(1)
            if not(_la==25 or _la==26):
                self._errHandler.recoverInline(self)
            else:
                self._errHandler.reportMatch(self)
                self.consume()
            self.state = 668
            self.match(qasm3Parser.ARRAY)
            self.state = 669
            self.match(qasm3Parser.LBRACKET)
            self.state = 670
            self.scalarType()
            self.state = 671
            self.match(qasm3Parser.COMMA)
            self.state = 676
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [30, 31, 32, 33, 34, 35, 36, 37, 39, 40, 47, 52, 57, 67, 78, 79, 85, 86, 87, 88, 89, 90, 91, 92, 93, 94]:
                self.state = 672
                self.expressionList()
                pass
            elif token in [46]:
                self.state = 673
                self.match(qasm3Parser.DIM)
                self.state = 674
                self.match(qasm3Parser.EQUALS)
                self.state = 675
                self.expression(0)
                pass
            else:
                raise NoViableAltException(self)

            self.state = 678
            self.match(qasm3Parser.RBRACKET)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class DesignatorContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def LBRACKET(self):
            return self.getToken(qasm3Parser.LBRACKET, 0)

        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)


        def RBRACKET(self):
            return self.getToken(qasm3Parser.RBRACKET, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_designator

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDesignator" ):
                listener.enterDesignator(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDesignator" ):
                listener.exitDesignator(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitDesignator" ):
                return visitor.visitDesignator(self)
            else:
                return visitor.visitChildren(self)




    def designator(self):

        localctx = qasm3Parser.DesignatorContext(self, self._ctx, self.state)
        self.enterRule(localctx, 100, self.RULE_designator)
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 680
            self.match(qasm3Parser.LBRACKET)
            self.state = 681
            self.expression(0)
            self.state = 682
            self.match(qasm3Parser.RBRACKET)
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class DefcalTargetContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def MEASURE(self):
            return self.getToken(qasm3Parser.MEASURE, 0)

        def RESET(self):
            return self.getToken(qasm3Parser.RESET, 0)

        def DELAY(self):
            return self.getToken(qasm3Parser.DELAY, 0)

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_defcalTarget

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDefcalTarget" ):
                listener.enterDefcalTarget(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDefcalTarget" ):
                listener.exitDefcalTarget(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitDefcalTarget" ):
                return visitor.visitDefcalTarget(self)
            else:
                return visitor.visitChildren(self)




    def defcalTarget(self):

        localctx = qasm3Parser.DefcalTargetContext(self, self._ctx, self.state)
        self.enterRule(localctx, 102, self.RULE_defcalTarget)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 684
            _la = self._input.LA(1)
            if not((((_la - 48)) & ~0x3f) == 0 and ((1 << (_la - 48)) & 4398046511111) != 0):
                self._errHandler.recoverInline(self)
            else:
                self._errHandler.reportMatch(self)
                self.consume()
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class DefcalArgumentDefinitionContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def expression(self):
            return self.getTypedRuleContext(qasm3Parser.ExpressionContext,0)


        def argumentDefinition(self):
            return self.getTypedRuleContext(qasm3Parser.ArgumentDefinitionContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_defcalArgumentDefinition

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDefcalArgumentDefinition" ):
                listener.enterDefcalArgumentDefinition(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDefcalArgumentDefinition" ):
                listener.exitDefcalArgumentDefinition(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitDefcalArgumentDefinition" ):
                return visitor.visitDefcalArgumentDefinition(self)
            else:
                return visitor.visitChildren(self)




    def defcalArgumentDefinition(self):

        localctx = qasm3Parser.DefcalArgumentDefinitionContext(self, self._ctx, self.state)
        self.enterRule(localctx, 104, self.RULE_defcalArgumentDefinition)
        try:
            self.state = 688
            self._errHandler.sync(self)
            la_ = self._interp.adaptivePredict(self._input,74,self._ctx)
            if la_ == 1:
                self.enterOuterAlt(localctx, 1)
                self.state = 686
                self.expression(0)
                pass

            elif la_ == 2:
                self.enterOuterAlt(localctx, 2)
                self.state = 687
                self.argumentDefinition()
                pass


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class DefcalOperandContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def HardwareQubit(self):
            return self.getToken(qasm3Parser.HardwareQubit, 0)

        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_defcalOperand

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDefcalOperand" ):
                listener.enterDefcalOperand(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDefcalOperand" ):
                listener.exitDefcalOperand(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitDefcalOperand" ):
                return visitor.visitDefcalOperand(self)
            else:
                return visitor.visitChildren(self)




    def defcalOperand(self):

        localctx = qasm3Parser.DefcalOperandContext(self, self._ctx, self.state)
        self.enterRule(localctx, 106, self.RULE_defcalOperand)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 690
            _la = self._input.LA(1)
            if not(_la==90 or _la==91):
                self._errHandler.recoverInline(self)
            else:
                self._errHandler.reportMatch(self)
                self.consume()
        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class GateOperandContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def indexedIdentifier(self):
            return self.getTypedRuleContext(qasm3Parser.IndexedIdentifierContext,0)


        def HardwareQubit(self):
            return self.getToken(qasm3Parser.HardwareQubit, 0)

        def getRuleIndex(self):
            return qasm3Parser.RULE_gateOperand

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterGateOperand" ):
                listener.enterGateOperand(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitGateOperand" ):
                listener.exitGateOperand(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitGateOperand" ):
                return visitor.visitGateOperand(self)
            else:
                return visitor.visitChildren(self)




    def gateOperand(self):

        localctx = qasm3Parser.GateOperandContext(self, self._ctx, self.state)
        self.enterRule(localctx, 108, self.RULE_gateOperand)
        try:
            self.state = 694
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [90]:
                self.enterOuterAlt(localctx, 1)
                self.state = 692
                self.indexedIdentifier()
                pass
            elif token in [91]:
                self.enterOuterAlt(localctx, 2)
                self.state = 693
                self.match(qasm3Parser.HardwareQubit)
                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ExternArgumentContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def scalarType(self):
            return self.getTypedRuleContext(qasm3Parser.ScalarTypeContext,0)


        def arrayReferenceType(self):
            return self.getTypedRuleContext(qasm3Parser.ArrayReferenceTypeContext,0)


        def CREG(self):
            return self.getToken(qasm3Parser.CREG, 0)

        def designator(self):
            return self.getTypedRuleContext(qasm3Parser.DesignatorContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_externArgument

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterExternArgument" ):
                listener.enterExternArgument(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitExternArgument" ):
                listener.exitExternArgument(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitExternArgument" ):
                return visitor.visitExternArgument(self)
            else:
                return visitor.visitChildren(self)




    def externArgument(self):

        localctx = qasm3Parser.ExternArgumentContext(self, self._ctx, self.state)
        self.enterRule(localctx, 110, self.RULE_externArgument)
        self._la = 0 # Token type
        try:
            self.state = 702
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [30, 31, 32, 33, 34, 35, 36, 39, 40]:
                self.enterOuterAlt(localctx, 1)
                self.state = 696
                self.scalarType()
                pass
            elif token in [25, 26]:
                self.enterOuterAlt(localctx, 2)
                self.state = 697
                self.arrayReferenceType()
                pass
            elif token in [29]:
                self.enterOuterAlt(localctx, 3)
                self.state = 698
                self.match(qasm3Parser.CREG)
                self.state = 700
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==53:
                    self.state = 699
                    self.designator()


                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ArgumentDefinitionContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def scalarType(self):
            return self.getTypedRuleContext(qasm3Parser.ScalarTypeContext,0)


        def Identifier(self):
            return self.getToken(qasm3Parser.Identifier, 0)

        def qubitType(self):
            return self.getTypedRuleContext(qasm3Parser.QubitTypeContext,0)


        def CREG(self):
            return self.getToken(qasm3Parser.CREG, 0)

        def QREG(self):
            return self.getToken(qasm3Parser.QREG, 0)

        def designator(self):
            return self.getTypedRuleContext(qasm3Parser.DesignatorContext,0)


        def arrayReferenceType(self):
            return self.getTypedRuleContext(qasm3Parser.ArrayReferenceTypeContext,0)


        def getRuleIndex(self):
            return qasm3Parser.RULE_argumentDefinition

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterArgumentDefinition" ):
                listener.enterArgumentDefinition(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitArgumentDefinition" ):
                listener.exitArgumentDefinition(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitArgumentDefinition" ):
                return visitor.visitArgumentDefinition(self)
            else:
                return visitor.visitChildren(self)




    def argumentDefinition(self):

        localctx = qasm3Parser.ArgumentDefinitionContext(self, self._ctx, self.state)
        self.enterRule(localctx, 112, self.RULE_argumentDefinition)
        self._la = 0 # Token type
        try:
            self.state = 718
            self._errHandler.sync(self)
            token = self._input.LA(1)
            if token in [30, 31, 32, 33, 34, 35, 36, 39, 40]:
                self.enterOuterAlt(localctx, 1)
                self.state = 704
                self.scalarType()
                self.state = 705
                self.match(qasm3Parser.Identifier)
                pass
            elif token in [28]:
                self.enterOuterAlt(localctx, 2)
                self.state = 707
                self.qubitType()
                self.state = 708
                self.match(qasm3Parser.Identifier)
                pass
            elif token in [27, 29]:
                self.enterOuterAlt(localctx, 3)
                self.state = 710
                _la = self._input.LA(1)
                if not(_la==27 or _la==29):
                    self._errHandler.recoverInline(self)
                else:
                    self._errHandler.reportMatch(self)
                    self.consume()
                self.state = 711
                self.match(qasm3Parser.Identifier)
                self.state = 713
                self._errHandler.sync(self)
                _la = self._input.LA(1)
                if _la==53:
                    self.state = 712
                    self.designator()


                pass
            elif token in [25, 26]:
                self.enterOuterAlt(localctx, 4)
                self.state = 715
                self.arrayReferenceType()
                self.state = 716
                self.match(qasm3Parser.Identifier)
                pass
            else:
                raise NoViableAltException(self)

        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ArgumentDefinitionListContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def argumentDefinition(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ArgumentDefinitionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ArgumentDefinitionContext,i)


        def COMMA(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.COMMA)
            else:
                return self.getToken(qasm3Parser.COMMA, i)

        def getRuleIndex(self):
            return qasm3Parser.RULE_argumentDefinitionList

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterArgumentDefinitionList" ):
                listener.enterArgumentDefinitionList(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitArgumentDefinitionList" ):
                listener.exitArgumentDefinitionList(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitArgumentDefinitionList" ):
                return visitor.visitArgumentDefinitionList(self)
            else:
                return visitor.visitChildren(self)




    def argumentDefinitionList(self):

        localctx = qasm3Parser.ArgumentDefinitionListContext(self, self._ctx, self.state)
        self.enterRule(localctx, 114, self.RULE_argumentDefinitionList)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 720
            self.argumentDefinition()
            self.state = 725
            self._errHandler.sync(self)
            _alt = self._interp.adaptivePredict(self._input,80,self._ctx)
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt==1:
                    self.state = 721
                    self.match(qasm3Parser.COMMA)
                    self.state = 722
                    self.argumentDefinition() 
                self.state = 727
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,80,self._ctx)

            self.state = 729
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==62:
                self.state = 728
                self.match(qasm3Parser.COMMA)


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class DefcalArgumentDefinitionListContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def defcalArgumentDefinition(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.DefcalArgumentDefinitionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.DefcalArgumentDefinitionContext,i)


        def COMMA(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.COMMA)
            else:
                return self.getToken(qasm3Parser.COMMA, i)

        def getRuleIndex(self):
            return qasm3Parser.RULE_defcalArgumentDefinitionList

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDefcalArgumentDefinitionList" ):
                listener.enterDefcalArgumentDefinitionList(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDefcalArgumentDefinitionList" ):
                listener.exitDefcalArgumentDefinitionList(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitDefcalArgumentDefinitionList" ):
                return visitor.visitDefcalArgumentDefinitionList(self)
            else:
                return visitor.visitChildren(self)




    def defcalArgumentDefinitionList(self):

        localctx = qasm3Parser.DefcalArgumentDefinitionListContext(self, self._ctx, self.state)
        self.enterRule(localctx, 116, self.RULE_defcalArgumentDefinitionList)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 731
            self.defcalArgumentDefinition()
            self.state = 736
            self._errHandler.sync(self)
            _alt = self._interp.adaptivePredict(self._input,82,self._ctx)
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt==1:
                    self.state = 732
                    self.match(qasm3Parser.COMMA)
                    self.state = 733
                    self.defcalArgumentDefinition() 
                self.state = 738
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,82,self._ctx)

            self.state = 740
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==62:
                self.state = 739
                self.match(qasm3Parser.COMMA)


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class DefcalOperandListContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def defcalOperand(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.DefcalOperandContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.DefcalOperandContext,i)


        def COMMA(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.COMMA)
            else:
                return self.getToken(qasm3Parser.COMMA, i)

        def getRuleIndex(self):
            return qasm3Parser.RULE_defcalOperandList

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterDefcalOperandList" ):
                listener.enterDefcalOperandList(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitDefcalOperandList" ):
                listener.exitDefcalOperandList(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitDefcalOperandList" ):
                return visitor.visitDefcalOperandList(self)
            else:
                return visitor.visitChildren(self)




    def defcalOperandList(self):

        localctx = qasm3Parser.DefcalOperandListContext(self, self._ctx, self.state)
        self.enterRule(localctx, 118, self.RULE_defcalOperandList)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 742
            self.defcalOperand()
            self.state = 747
            self._errHandler.sync(self)
            _alt = self._interp.adaptivePredict(self._input,84,self._ctx)
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt==1:
                    self.state = 743
                    self.match(qasm3Parser.COMMA)
                    self.state = 744
                    self.defcalOperand() 
                self.state = 749
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,84,self._ctx)

            self.state = 751
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==62:
                self.state = 750
                self.match(qasm3Parser.COMMA)


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ExpressionListContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def expression(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExpressionContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExpressionContext,i)


        def COMMA(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.COMMA)
            else:
                return self.getToken(qasm3Parser.COMMA, i)

        def getRuleIndex(self):
            return qasm3Parser.RULE_expressionList

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterExpressionList" ):
                listener.enterExpressionList(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitExpressionList" ):
                listener.exitExpressionList(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitExpressionList" ):
                return visitor.visitExpressionList(self)
            else:
                return visitor.visitChildren(self)




    def expressionList(self):

        localctx = qasm3Parser.ExpressionListContext(self, self._ctx, self.state)
        self.enterRule(localctx, 120, self.RULE_expressionList)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 753
            self.expression(0)
            self.state = 758
            self._errHandler.sync(self)
            _alt = self._interp.adaptivePredict(self._input,86,self._ctx)
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt==1:
                    self.state = 754
                    self.match(qasm3Parser.COMMA)
                    self.state = 755
                    self.expression(0) 
                self.state = 760
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,86,self._ctx)

            self.state = 762
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==62:
                self.state = 761
                self.match(qasm3Parser.COMMA)


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class IdentifierListContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def Identifier(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.Identifier)
            else:
                return self.getToken(qasm3Parser.Identifier, i)

        def COMMA(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.COMMA)
            else:
                return self.getToken(qasm3Parser.COMMA, i)

        def getRuleIndex(self):
            return qasm3Parser.RULE_identifierList

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterIdentifierList" ):
                listener.enterIdentifierList(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitIdentifierList" ):
                listener.exitIdentifierList(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitIdentifierList" ):
                return visitor.visitIdentifierList(self)
            else:
                return visitor.visitChildren(self)




    def identifierList(self):

        localctx = qasm3Parser.IdentifierListContext(self, self._ctx, self.state)
        self.enterRule(localctx, 122, self.RULE_identifierList)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 764
            self.match(qasm3Parser.Identifier)
            self.state = 769
            self._errHandler.sync(self)
            _alt = self._interp.adaptivePredict(self._input,88,self._ctx)
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt==1:
                    self.state = 765
                    self.match(qasm3Parser.COMMA)
                    self.state = 766
                    self.match(qasm3Parser.Identifier) 
                self.state = 771
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,88,self._ctx)

            self.state = 773
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==62:
                self.state = 772
                self.match(qasm3Parser.COMMA)


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class GateOperandListContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def gateOperand(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.GateOperandContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.GateOperandContext,i)


        def COMMA(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.COMMA)
            else:
                return self.getToken(qasm3Parser.COMMA, i)

        def getRuleIndex(self):
            return qasm3Parser.RULE_gateOperandList

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterGateOperandList" ):
                listener.enterGateOperandList(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitGateOperandList" ):
                listener.exitGateOperandList(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitGateOperandList" ):
                return visitor.visitGateOperandList(self)
            else:
                return visitor.visitChildren(self)




    def gateOperandList(self):

        localctx = qasm3Parser.GateOperandListContext(self, self._ctx, self.state)
        self.enterRule(localctx, 124, self.RULE_gateOperandList)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 775
            self.gateOperand()
            self.state = 780
            self._errHandler.sync(self)
            _alt = self._interp.adaptivePredict(self._input,90,self._ctx)
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt==1:
                    self.state = 776
                    self.match(qasm3Parser.COMMA)
                    self.state = 777
                    self.gateOperand() 
                self.state = 782
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,90,self._ctx)

            self.state = 784
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==62:
                self.state = 783
                self.match(qasm3Parser.COMMA)


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx


    class ExternArgumentListContext(ParserRuleContext):
        __slots__ = 'parser'

        def __init__(self, parser, parent:ParserRuleContext=None, invokingState:int=-1):
            super().__init__(parent, invokingState)
            self.parser = parser

        def externArgument(self, i:int=None):
            if i is None:
                return self.getTypedRuleContexts(qasm3Parser.ExternArgumentContext)
            else:
                return self.getTypedRuleContext(qasm3Parser.ExternArgumentContext,i)


        def COMMA(self, i:int=None):
            if i is None:
                return self.getTokens(qasm3Parser.COMMA)
            else:
                return self.getToken(qasm3Parser.COMMA, i)

        def getRuleIndex(self):
            return qasm3Parser.RULE_externArgumentList

        def enterRule(self, listener:ParseTreeListener):
            if hasattr( listener, "enterExternArgumentList" ):
                listener.enterExternArgumentList(self)

        def exitRule(self, listener:ParseTreeListener):
            if hasattr( listener, "exitExternArgumentList" ):
                listener.exitExternArgumentList(self)

        def accept(self, visitor:ParseTreeVisitor):
            if hasattr( visitor, "visitExternArgumentList" ):
                return visitor.visitExternArgumentList(self)
            else:
                return visitor.visitChildren(self)




    def externArgumentList(self):

        localctx = qasm3Parser.ExternArgumentListContext(self, self._ctx, self.state)
        self.enterRule(localctx, 126, self.RULE_externArgumentList)
        self._la = 0 # Token type
        try:
            self.enterOuterAlt(localctx, 1)
            self.state = 786
            self.externArgument()
            self.state = 791
            self._errHandler.sync(self)
            _alt = self._interp.adaptivePredict(self._input,92,self._ctx)
            while _alt!=2 and _alt!=ATN.INVALID_ALT_NUMBER:
                if _alt==1:
                    self.state = 787
                    self.match(qasm3Parser.COMMA)
                    self.state = 788
                    self.externArgument() 
                self.state = 793
                self._errHandler.sync(self)
                _alt = self._interp.adaptivePredict(self._input,92,self._ctx)

            self.state = 795
            self._errHandler.sync(self)
            _la = self._input.LA(1)
            if _la==62:
                self.state = 794
                self.match(qasm3Parser.COMMA)


        except RecognitionException as re:
            localctx.exception = re
            self._errHandler.reportError(self, re)
            self._errHandler.recover(self, re)
        finally:
            self.exitRule()
        return localctx



    def sempred(self, localctx:RuleContext, ruleIndex:int, predIndex:int):
        if self._predicates == None:
            self._predicates = dict()
        self._predicates[35] = self.expression_sempred
        pred = self._predicates.get(ruleIndex, None)
        if pred is None:
            raise Exception("No predicate with index:" + str(ruleIndex))
        else:
            return pred(localctx, predIndex)

    def expression_sempred(self, localctx:ExpressionContext, predIndex:int):
            if predIndex == 0:
                return self.precpred(self._ctx, 16)
         

            if predIndex == 1:
                return self.precpred(self._ctx, 14)
         

            if predIndex == 2:
                return self.precpred(self._ctx, 13)
         

            if predIndex == 3:
                return self.precpred(self._ctx, 12)
         

            if predIndex == 4:
                return self.precpred(self._ctx, 11)
         

            if predIndex == 5:
                return self.precpred(self._ctx, 10)
         

            if predIndex == 6:
                return self.precpred(self._ctx, 9)
         

            if predIndex == 7:
                return self.precpred(self._ctx, 8)
         

            if predIndex == 8:
                return self.precpred(self._ctx, 7)
         

            if predIndex == 9:
                return self.precpred(self._ctx, 6)
         

            if predIndex == 10:
                return self.precpred(self._ctx, 5)
         

            if predIndex == 11:
                return self.precpred(self._ctx, 17)
         




