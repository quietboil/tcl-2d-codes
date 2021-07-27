##
# ECC 200 DataMatrix generator for TCL
#
# Copyright (c) 2021 by Alexander Demenchuk <alexander.demenchuk@gmail.com>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
#
package provide datamatrix 1.0

namespace eval ::datamatrix {

    set symbolsDataCapacity {
        3   5   8  12  18  22  30  36  44  62  86  114  144  174  204  280  368  456  576  696  816  1050  1304  1558
    }

    set symbolSizes {
       10  12  14  16  18  20  22  24  26  32  36   40   44   48   52   64   72   80   88   96  104   120   132   144
    }

    set symbolMatrixSizes {
        8  10  12  14  16  18  20  22  24  28  32   36   40   44   48   56   64   72   80   88   96   108   120   132
    }

    set dataRegionSizes {
        8  10  12  14  16  18  20  22  24  14  16   18   20   22   24   14   16   18   20   22   24    18    20    22
    }

    set blockInterleave {
        1   1   1   1   1   1   1   1   1   1   1    1    1    1    2    2    4    4    4    4    6     6     8    10
    }

    set numBlockErrorCorrectionWords {
        5   7  10  12  14  18  20  24  28  36  42   48   56   68   42   56   36   48   56   68   56    68    62    62
    }

    ##
    # Builds datamatrix symbol for the provided text
    #
    # @param text message to be represented in the datamatrix
    # @return matrix (list of lists) of bits (1 for dark, 0 for light)
    #         that include both data and finder patterns
    #
    # @exception messsage has characters that are not representable in ISO-8859-1
    # @exception message is too long to be placed even into the largest matrix
    #
    # @test
    #   ::datamatrix::make "123456" >>
    #        1 0 1 0 1 0 1 0 1 0
    #        1 1 0 0 1 0 1 1 0 1
    #        1 1 0 0 0 0 0 1 0 0
    #        1 1 0 0 0 1 1 1 0 1
    #        1 1 0 0 0 0 1 0 0 0
    #        1 0 0 0 0 0 1 1 1 1
    #        1 1 1 0 1 1 0 0 0 0
    #        1 1 1 1 0 1 1 0 0 1
    #        1 0 0 1 1 1 0 1 0 0
    #        1 1 1 1 1 1 1 1 1 1
    #
    proc make { text } {
        set data [encode $text]
        set version [findSymbol [llength $data]]
        padEncodedMessage data $version
        addErrorCorrection data $version

        variable symbolMatrixSizes

        set matrixSize [lindex $symbolMatrixSizes $version]
        set dataMatrix [lrepeat $matrixSize [lrepeat $matrixSize {} ]]
        putDataIntoMatrix dataMatrix $data

        variable symbolSizes
        variable dataRegionSizes

        set symbolSize [lindex $symbolSizes $version]
        set regionSize [lindex $dataRegionSizes $version]
        set regionEnd  [expr $regionSize - 1 ]
        set numRegions [expr $matrixSize / $regionSize ]

        set symbol [list]
        set symbolRow 0
        set dataRow -1
        for { set v 0 } { $v < $numRegions } { incr v } {
            # draw the horizontal clock pattern through all horizonal regions
            lappend symbol [lrepeat [expr $symbolSize / 2] 1 0]
            incr symbolRow
            for { set n 0 } { $n < $regionSize } { incr n } {
                # build the symbol row by interleaving row data bits for each
                # region with vertical finder and clock patterns
                set dataRowBits [lindex $dataMatrix [incr dataRow]]
                set dataCol 0
                set symbolRowBits [list]
                for { set h 0 } { $h < $numRegions } { incr h } {
                    # vertical finder module
                    lappend symbolRowBits 1
                    # copy row of data bits for the region
                    lappend symbolRowBits {*}[lrange $dataRowBits $dataCol $dataCol+$regionEnd]
                    # vertical clock module
                    lappend symbolRowBits [expr $symbolRow % 2]
                    incr dataCol $regionSize
                }
                lappend symbol $symbolRowBits
                incr symbolRow
            }
            # draw the horizontal finder pattern
            lappend symbol [lrepeat $symbolSize 1]
            incr symbolRow
        }
        return $symbol
    }

    ##
    # Encodes the text message into datamatrix bytes with added error correction.
    #
    # @param text text to be represented as datamatrix
    # @return list of data bytes
    # @exception text has characters that cannot be represented in the ISO-8859-1 encoding
    # @exception message is too long to be placed even into the largest matrix
    #
    # @test
    #  encode "123456"  == {142 164 186}
    #  encode "±123456" == {235 50 142 164 186}
    #
    proc encode { text } {
        set text [convertToISO $text]

        set data [list]
        if { [regexp {^\[\)>\u001e05\u001d.*\u001e\u0004$} $text] } {
            lappend data 236 ;# Macro 05
            set text [string range $text 7 end-2]
        } elseif { [regexp {^\[\)>\u001e06\u001d.*\u001e\u0004$} $text] } {
            lappend data 237 ;# Macro 06
            set text [string range $text 7 end-2]
        }

        variable symbolsDataCapacity

        set from 0
        set textEnd [string length $text]
        while { $from < $textEnd } {
            lassign [selectEncoder $text $from] encoder end
            switch $encoder {
                c40     { lappend data 230 }
                t40     { lappend data 239 }
                base256 { lappend data 231 }
            }
            switch $encoder {
                digits  { encodeDigits  data $text $from $end }
                ascii   { encodeASCII   data $text $from $end }
                c40     { encodeC40     data $text $from $end }
                t40     { encodeT40     data $text $from $end }
                base256 { encodeBase256 data $text $from $end }
                default { return -code error "unknown encoder $encoder" }
            }
            if { $end < $textEnd || [llength $data] < [lindex $symbolsDataCapacity [findSymbol [llength $data]]] } {
                switch $encoder {
                    c40     { lappend data 254 }
                    t40     { lappend data 254 }
                }
            }
            set from $end
        }
        return $data
    }

    ##
    # Converts text into ISO-8859-1 and ensures that the conversion was successful.
    #
    # @param text text to encode
    # @return ISO-8859-1 encoded text
    # @exception text has characters that cannot be encoded as ISO-8859-1
    #
    proc convertToISO { text } {
        set isotext [encoding convertto iso8859-1 $text]
        set i [string first "?" $isotext]
        while { $i >= 0 } {
            if { [string index $text $i] != "?" } {
                return -code error "Message contains characters outside ISO-8859-1 encoding"
            }
            set i [string first "?" $isotext $i+1]
        }
        return $isotext
    }

    ##
    # Examines the remaining text and select the next encoder that ensures the
    # minimal encoding of the message
    #
    # @param text input text
    # @param from review text starting with the charater at this position
    # @return list with 2 elements - selected encoder and the end index (after the last character)
    #
    proc selectEncoder { text from } {
        set asciiEnd [string length $text]

        if { [regexp -start $from -indices {[0-9]+} $text range] } {
            lassign $range start end
            incr end
            if { $start == $from } {
                set numDigits [expr $end - $from ]
                if { $numDigits >= 2 } {
                    if { $numDigits % 2 != 0 } {
                        incr end -1
                    }
                    return [list digits $end]
                }
                set asciiEnd [expr min($asciiEnd, $end) ]
            } else {
                set asciiEnd [expr min($asciiEnd, $start) ]
            }
        }
        # C40
        if { [regexp -start $from -indices {[ 0-9A-Z]+} $text range] } {
            lassign $range start end
            incr end
            if { $start == $from } {
                # We need to insert latch and unlatch characters for C40, so unless we have 9
                # or more C40 characters ahead (6 puts it even with ASCII), we won't even try.
                if { $end - $start >= 9 } {
                    # we would only handle groups of 3 and fall back to ASCII for the rest.
                    set end [expr $end - ($end - $start) % 3 ]
                    return [list c40 $end]
                }
                set asciiEnd [expr min($asciiEnd, $end) ]
            } else {
                set asciiEnd [expr min($asciiEnd, $start) ]
            }
        }
        # Text
        # Is a variant of C40 for low-case characters, so... same rules
        if { [regexp -start $from -indices {[ 0-9a-z]+} $text range] } {
            lassign $range start end
            incr end
            if { $start == $from } {
                # We need to insert latch and unlatch characters for C40, so unless we have 9
                # or more C40 characters ahead (6 puts it even with ASCII), we won't even try.
                if { $end - $start >= 9 } {
                    # we would only handle groups of 3 and fall back to ASCII for the rest.
                    set end [expr $end - ($end - $start) % 3 ]
                    return [list t40 $end]
                }
                set asciiEnd [expr min($asciiEnd, $end) ]
            } else {
                set asciiEnd [expr min($asciiEnd, $start) ]
            }
        }
        # Base 256
        if { [regexp -start $from -indices {[\x80-\xff]+} $text range] } {
            lassign $range start end
            incr end
            if { $start == $from } {
                # Becuase of the latch and the length field it would make sense to use it instead of
                # ASCII if it has at least 3 characters (2 makes it even with ASCII)
                if { $end - $start >= 3 } {
                    if { $end - $start > 1555 } {
                        return -code error "Message is too long. It exceeds capacity of even the biggest symbol."
                    }
                    return [list base256 $end]
                }
                set asciiEnd [expr min($asciiEnd, $end) ]
            } else {
                set asciiEnd [expr min($asciiEnd, $start) ]
            }
        }
        # ASCII
        #
        return [list ascii $asciiEnd ]
    }

    ##
    # Encodes the even number of digits
    #
    # @param dataVar reference to the encoded data list
    # @param text input text
    # @param from start of the encoding range of characters
    # @param from end (exclusive) start of the encoding range of characters
    #
    proc encodeDigits { dataVar text from end } {
        upvar $dataVar data

        while { $from < $end } {
            set val [scan [string range $text $from $from+1] %d]
            lappend data [expr 130 + $val ]
            incr from 2
        }
    }

    ##
    # Encodes text string
    #
    # @param dataVar reference to the encoded data list
    # @param text input text
    # @param from start of the encoding range of characters
    # @param from end (exclusive) start of the encoding range of characters
    #
    proc encodeASCII { dataVar text from end } {
        upvar $dataVar data

        while { $from < $end } {
            set val [scan [string index $text $from] %c]
            if { $val < 128 } {
                lappend data [expr $val + 1 ]
            } else {
                lappend data 235 [expr $val - 128 + 1 ]
            }
            incr from
        }
    }

    ##
    # Encodes text that can be represented using C40 character set.
    #
    # @param dataVar reference to the encoded data list
    # @param text input text
    # @param from start of the encoding range of characters
    # @param from end (exclusive) start of the encoding range of characters
    #
    proc encodeC40 { dataVar text from end } {
        upvar $dataVar data

        while { $from < $end } {
            set val [expr {
                1600 * [getC40Code $text $from  ] +
                  40 * [getC40Code $text $from+1] +
                       [getC40Code $text $from+2] + 1
            }]
            lappend data [expr $val >> 8 ] [expr $val & 0xff ]
            incr from 3
        }
    }

    ##
    # Returns C40 code of a character
    #
    # @param dataVar reference to the encoded data list
    # @param text input text
    # @param idx index of the character
    # @return C40 character code
    #
    proc getC40Code { text idx } {
        set char [string index $text [expr $idx]]
        if { $char == " " } {
            return 3
        }
        if { "0" <= $char && $char <= "9" } {
            return [expr [scan $char %c] - 48 + 4 ]
        }
        # A..Z
        return [expr [scan $char %c] - 65 + 14 ]
    }

    ##
    # Encodes text that can be represented using "T40" character set.
    #
    # @param dataVar reference to the encoded data list
    # @param text input text
    # @param from start of the encoding range of characters
    # @param from end (exclusive) start of the encoding range of characters
    #
    proc encodeT40 { dataVar text from end } {
        upvar $dataVar data

        while { $from < $end } {
            set val [expr {
                1600 * [getT40Code $text $from  ] +
                  40 * [getT40Code $text $from+1] +
                       [getT40Code $text $from+2] + 1
            }]
            lappend data [expr $val >> 8 ] [expr $val & 0xff ]
            incr from 3
        }
    }

    ##
    # Returns "T40" code of a character
    #
    # @param dataVar reference to the encoded data list
    # @param text input text
    # @param idx index of the character
    # @return C40 character code
    #
    proc getT40Code { text idx } {
        set char [string index $text [expr $idx]]
        if { $char == " " } {
            return 3
        }
        if { "0" <= $char && $char <= "9" } {
            return [expr [scan $char %c] - 48 + 4 ]
        }
        # a..z
        return [expr [scan $char %c] - 97 + 14 ]
    }

    ##
    # Encodes text as 8-bit bytes
    #
    # @param dataVar reference to the encoded data list
    # @param text input text
    # @param from start of the encoding range of characters
    # @param from end (exclusive) start of the encoding range of characters
    #
    proc encodeBase256 { dataVar text from end } {
        upvar $dataVar data

        set len [expr $end - $from ]
        if { $len <= 249 } {
            lappend data $len
        } else {
            lappend data [expr $len / 250 + 249 ] [expr $len % 250 ]
        }
        while { $from < $end } {
            lappend data [scan [string index $text $from] %c]
            incr from
        }
    }


    ##
    # Pads encoded data to fill the tail of the data buffer with pseudo random data.
    #
    # @param dataVar reference to the encoded data list
    # @param version datamatrix version
    #
    proc padEncodedMessage { dataVar version } {
        variable symbolsDataCapacity

        upvar $dataVar data

        set symbolCapacity [lindex $symbolsDataCapacity $version]
        set pos [llength $data]
        if { $pos < $symbolCapacity } {
            lappend data 129
        }
        while { [incr pos] < $symbolCapacity } {
            # fill the tail with pseudo random data
            set rnd [expr { 129 + 149 * $pos % 253 + 1 }]
            if { $rnd > 254 } {
                incr rnd -254
            }
            lappend data $rnd
        }
    }

    ##
    # Finds the datamatrix symbol that can fit the specified number of code words.
    #
    # @param dataLength number of codewords that would be placed into the symbol
    # @return version of the datamatrix
    # @exception text is too long and cannot fit into any symbol
    #
    # @note that only square symbols are supported at the moment
    #
    proc findSymbol { dataLength } {
        variable symbolsDataCapacity

        for { set version 0 } { $version < 24 } { incr version } {
            if { [lindex $symbolsDataCapacity $version] >= $dataLength } {
                break
            }
        }
        if { $version == 24 } {
            return -code error "Message is too long. It exceeds capacity of even the biggest symbol."
        }
        return $version
    }

    ##
    # Adds error correction data to the message.
    #
    # @param dataVar reference to the encoded data list
    # @param version datamatrix version
    #
    proc addErrorCorrection { dataVar version } {
        variable numBlockErrorCorrectionWords

        upvar $dataVar data

        set eccLength [lindex $numBlockErrorCorrectionWords $version]
        set eccBlocks [rsBlockErrorCorrection $data $version]
        set numBlocks [llength $eccBlocks]
        if { $numBlocks == 1 } {
            lappend data {*}[lindex $eccBlocks 0]
        } else {
            for { set i 0 } { $i < $eccLength } { incr i } {
                for { set b 0 } { $b < $numBlocks } { incr b } {
                    lappend data [lindex $eccBlocks $b $i]
                }
            }
        }
    }

    array set generatorPolynomials {
         5 {235 207 210 244 15}
         7 {177 30 214 218 42 197 28}
        10 {199 50 150 120 237 131 172 83 243 55}
        12 {168 142 35 173 94 185 107 199 74 194 233 78}
        14 {83 171 33 39 8 12 248 27 38 84 93 246 173 105}
        18 {164 9 244 69 177 163 161 231 94 250 199 220 253 164 103 142 61 171}
        20 {127 33 146 23 79 25 193 122 209 233 230 164 1 109 184 149 38 201 61 210}
        24 {65 141 245 31 183 242 236 177 127 225 106 22 131 20 202 22 106 137 103 231 215 136 85 45}
        28 {150 32 109 149 239 213 198 48 94 50 12 195 167 130 196 253 99 166 239 222 146 190 245 184 173 125 17 151}
        36 {57 86 187 69 140 153 31 66 135 67 248 84 90 81 219 197 2 1 39 16 75 229 20 51 252 108 213 181 183 87 111 77 232 168 176 156}
        42 {225 38 225 148 192 254 141 11 82 237 81 24 13 122 255 106 167 13 207 160 88 203 38 142 84 66 3 168 102 156 1 200 88 60 233 134 115 114 234 90 65 138}
        48 {114 69 122 30 94 11 66 230 132 73 145 137 135 79 214 33 12 220 142 213 136 124 215 166 9 222 28 154 132 4 100 170 145 59 164 215 17 249 102 249 134 128 5 245 131 127 221 156}
        56 {29 179 99 149 159 72 125 22 55 60 217 176 156 90 43 80 251 235 128 169 254 134 249 42 121 118 72 128 129 232 37 15 24 221 143 115 131 40 113 254 19 123 246 68 166 66 118 142 47 51 195 242 249 131 38 66}
        62 {182 133 162 126 236 58 172 163 53 121 159 2 166 137 234 158 195 164 77 228 226 145 91 180 232 23 241 132 135 206 184 14 6 66 238 83 100 111 85 202 91 156 68 218 57 83 222 188 25 179 144 169 164 82 154 103 89 42 141 175 32 168}
        68 {33 79 190 245 91 221 233 25 24 6 144 151 121 186 140 127 45 153 250 183 70 131 198 17 89 245 121 51 140 252 203 82 83 233 152 220 155 18 230 210 94 32 200 197 192 194 202 129 10 237 198 94 176 36 40 139 201 132 219 34 56 113 52 20 34 247 15 51}
    }

    set log {
        0 255 1 240 2 225 241 53 3 38 226 133 242 43 54 210 4 195 39 114 227 106 134 28 243 140 44 23 55 118 211 234 5 219 196 96 40 222 115 103 228 78 107 125 135 8 29 162 244 186 141 180 45 99 24 49 56 13 119 153 212 199 235 91 6 76 220 217 197 11 97 184 41 36 223 253 116 138 104 193 229 86 79 171 108 165 126 145 136 34 9 74 30 32 163 84 245 173 187 204 142 81 181 190 46 88 100 159 25 231 50 207 57 147 14 67 120 128 154 248 213 167 200 63 236 110 92 176 7 161 77 124 221 102 218 95 198 90 12 152 98 48 185 179 42 209 37 132 224 52 254 239 117 233 139 22 105 27 194 113 230 206 87 158 80 189 172 203 109 175 166 62 127 247 146 66 137 192 35 252 10 183 75 216 31 83 33 73 164 144 85 170 246 65 174 61 188 202 205 157 143 169 82 72 182 215 191 251 47 178 89 151 101 94 160 123 26 112 232 21 51 238 208 131 58 69 148 18 15 16 68 17 121 149 129 19 155 59 249 70 214 250 168 71 201 156 64 60 237 130 111 20 93 122 177 150
    }

    set alog {
        1 2 4 8 16 32 64 128 45 90 180 69 138 57 114 228 229 231 227 235 251 219 155 27 54 108 216 157 23 46 92 184 93 186 89 178 73 146 9 18 36 72 144 13 26 52 104 208 141 55 110 220 149 7 14 28 56 112 224 237 247 195 171 123 246 193 175 115 230 225 239 243 203 187 91 182 65 130 41 82 164 101 202 185 95 190 81 162 105 210 137 63 126 252 213 135 35 70 140 53 106 212 133 39 78 156 21 42 84 168 125 250 217 159 19 38 76 152 29 58 116 232 253 215 131 43 86 172 117 234 249 223 147 11 22 44 88 176 77 154 25 50 100 200 189 87 174 113 226 233 255 211 139 59 118 236 245 199 163 107 214 129 47 94 188 85 170 121 242 201 191 83 166 97 194 169 127 254 209 143 51 102 204 181 71 142 49 98 196 165 103 206 177 79 158 17 34 68 136 61 122 244 197 167 99 198 161 111 222 145 15 30 60 120 240 205 183 67 134 33 66 132 37 74 148 5 10 20 40 80 160 109 218 153 31 62 124 248 221 151 3 6 12 24 48 96 192 173 119 238 241 207 179 75 150 1
    }

    ##
    # Returns error correction code words for the specified part of the text.
    #
    # @param data list of bytes for one of the reed-solomon blocks
    # @param version datamatrix version
    # @return list of lists of error correction bytes
    #
    # @test
    #  - rsBlockErrorCorrection {142 164 186} 0 = { {114 25 5 88 102} }
    #
    proc rsBlockErrorCorrection { data version } {
        variable blockInterleave
        variable numBlockErrorCorrectionWords
        variable generatorPolynomials

        set ecclen  [lindex $numBlockErrorCorrectionWords $version]
        set eccEnd  [expr { $ecclen - 1 }]
        set gen     $generatorPolynomials($ecclen)
        set dataLen [llength $data]
        set stride  [lindex $blockInterleave $version]

        set eccDataEnd [expr { $ecclen - 1 }]
        set eccDataLen [expr { $ecclen * $stride }]
        set eccData [list]

        for { set block 0 } { $block < $stride } { incr block } {
            set ecc [lrepeat $ecclen 0]
            for { set i $block } { $i < $dataLen } { incr i $stride } {
                set val [expr [lindex $ecc 0] ^ [lindex $data $i] ]
                for { set j 0 } { $j < $eccEnd } { incr j } {
                    lset ecc $j [expr [lindex $ecc $j+1] ^ [gfprod [lindex $gen $j] $val] ]
                }
                lset ecc $j [gfprod [lindex $gen $j] $val]
            }
            lappend eccData $ecc
        }
        return $eccData
    }

    ##
    # Multiplies 2 term coefficients in GF(255) space,
    # i.e. it adds exponents, ensures the sum is mod 255
    # and maps the result back into pow(2) coefficient in
    # GF(255) space
    #
    # @param exp exponent of the generator polynomial
    # @param val a GF(255) value
    # @return product (as a GF(255) value)
    #
    proc gfprod { exp val } {
        variable log
        variable alog

        if { $val == 0 } {
            # then exp = 0; return alog(exp)
            return 1
        }
        return [lindex $alog [expr ($exp + [lindex $log $val]) % 255 ]]
    }

    ##
    # Places data bits into the datamatrix
    #
    # @param matrixVar reference to the datamatrix (list of lists)
    # @param data encoded data
    #
    # @test
    #   set matrix [lrepeat 8 [lrepeat 8 {}]]
    #   ::datamatrix::putDataIntoMatrix matrix [::datamatrix::encode "123456"] >>
    #        1 0 0 1 0 1 1 0
    #        1 0 0 0 0 0 1 0
    #        1 0 0 0 1 1 1 0
    #        1 0 0 0 0 1 0 0
    #        0 0 0 0 0 1 1 1
    #        1 1 0 1 1 0 0 0
    #        1 1 1 0 1 1 0 0
    #        0 0 1 1 1 0 1 0
    #
    proc putDataIntoMatrix { matrixVar data } {
        upvar $matrixVar matrix

        set numrows [llength $matrix]
        set numcols [llength $matrix]

        set pos -1
        set row 4
        set col 0
        do {
            # first check for one of the special corner cases
            if { $row == $numrows && $col == 0 } {
                corner1 matrix [lindex $data [incr pos]]
            } elseif { $row == $numrows - 2 && $col == 0 && $numcols % 4 != 0 } {
                corner2 matrix [lindex $data [incr pos]]
            } elseif { $row == $numrows - 2 && $col == 0 && $numcols % 8 == 4 } {
                corner3 matrix [lindex $data [incr pos]]
            } elseif { $row == $numrows + 4 && $col == 2 && $numcols % 8 == 0 } {
                corner4 matrix [lindex $data [incr pos]]
            }
            # then sweep upward diagonally, inserting successive characters
            do {
                if { $row < $numrows && $col >= 0 && [lindex $matrix $row $col] == {} } {
                    utah matrix $row $col [lindex $data [incr pos]]
                }
                incr row -2
                incr col 2
            } while { $row >= 0 && $col < $numcols }
            incr row
            incr col 3

            # and then sweep downward diagonally, inserting successive characters
            do {
                if { $row >= 0 && $col < $numcols && [lindex $matrix $row $col] == {} } {
                    utah matrix $row $col [lindex $data [incr pos]]
                }
                incr row  2
                incr col -2
            } while { $row < $numrows && $col >= 0 }
            incr row 3
            incr col
            # until the entire array is scanned
        } while { $row < $numrows || $col < $numcols }

        # Lastly, if the lower right-hand corner is untouched, fill in fixed pattern
        if { [lindex $matrix $numrows-1 $numcols-1] == {} } {
            lset matrix $numrows-1 $numcols-1 1
            lset matrix $numrows-2 $numcols-2 1
        }
    }

    ##
    # Helper syntax contruct
    # do {
    #   stuff
    # } while { cond }
    #
    proc do { block while cond } {
        uplevel $block
        while { [uplevel expr $cond] } {
            uplevel $block
        }
    }

    ##
    # Draws a single bit (module).
    #
    # @param matrixVar reference to the datamatrix (list of lists)
    # @param row row where the bit should be set
    # @param col columns where the bit should be set
    # @param val byte which bits are being placed
    # @param bit bit number. Bits are numbered from 1 (MSB) to 8 (LSB)
    #
    proc module { matrixVar row col val bit } {
        upvar $matrixVar matrix

        set numrows [llength $matrix]
        set numcols [llength $matrix]

        set row [expr $row]
        set col [expr $col]

        if { $row < 0 } {
            incr row $numrows
            incr col [expr { 4 - ($numrows + 4) % 8 }]
        }
        if { $col < 0 } {
            incr col $numcols
            incr row [expr { 4 - ($numcols + 4) % 8 }]
        }
        lset matrix $row $col [expr ($val & (1 << (8 - $bit))) != 0 ]
    }

    ##
    # Places 8 bits of a byte in an L-shape pattern:
    #   1 2
    #   3 4 5
    #   6 7 8
    #
    # @param matrixVar reference to the datamatrix (list of lists)
    # @param row row of the LS bit (spec calls it bit #8)
    # @param col column of the LS bit
    # @param val byte to place
    #
    proc utah { matrixVar row col val } {
        upvar $matrixVar matrix
        module matrix $row-2 $col-2 $val 1
        module matrix $row-2 $col-1 $val 2
        module matrix $row-1 $col-2 $val 3
        module matrix $row-1 $col-1 $val 4
        module matrix $row-1 $col   $val 5
        module matrix $row   $col-2 $val 6
        module matrix $row   $col-1 $val 7
        module matrix $row   $col   $val 8
    }


    ##
    #  |         4 5
    #  |           6
    #  |           7
    #  |           8
    #  | . . .
    #  | 1 2 3
    #  --------------
    #
    # @param matrixVar reference to the datamatrix (list of lists)
    # @param val byte to place
    #
    proc corner1 { matrixVar val } {
        upvar $matrixVar matrix

        set numrows [llength $matrix]
        set numcols [llength $matrix]

        module matrix $numrows-1 0 $val 1
        module matrix $numrows-1 1 $val 2
        module matrix $numrows-1 2 $val 3
        module matrix 0 $numcols-2 $val 4
        module matrix 0 $numcols-1 $val 5
        module matrix 1 $numcols-1 $val 6
        module matrix 2 $numcols-1 $val 7
        module matrix 3 $numcols-1 $val 8
    }

    ##
    #  |     4 5 6 7
    #  |           8
    #  |............
    #  |1
    #  |2
    #  |3
    #  --------------
    #
    # @param matrixVar reference to the datamatrix (list of lists)
    # @param val byte to place
    #
    proc corner2 { matrixVar val } {
        upvar $matrixVar matrix

        set numrows [llength $matrix]
        set numcols [llength $matrix]

        module matrix $numrows-3 0 $val 1
        module matrix $numrows-2 0 $val 2
        module matrix $numrows-1 0 $val 3
        module matrix 0 $numcols-4 $val 4
        module matrix 0 $numcols-3 $val 5
        module matrix 0 $numcols-2 $val 6
        module matrix 0 $numcols-1 $val 7
        module matrix 1 $numcols-1 $val 8
    }

    ##
    #  |        4 5
    #  |          6
    #  |          7
    #  |          8
    #  |............
    #  |1
    #  |2
    #  |3
    #  --------------
    #
    # @param matrixVar reference to the datamatrix (list of lists)
    # @param val byte to place
    #
    proc corner3 { matrixVar val } {
        upvar $matrixVar matrix

        set numrows [llength $matrix]
        set numcols [llength $matrix]

        module matrix $numrows-3 0 $val 1
        module matrix $numrows-2 0 $val 2
        module matrix $numrows-1 0 $val 3
        module matrix 0 $numcols-2 $val 4
        module matrix 0 $numcols-1 $val 5
        module matrix 1 $numcols-1 $val 6
        module matrix 2 $numcols-1 $val 7
        module matrix 3 $numcols-1 $val 8
    }

    ##
    #  |        3 4 5
    #  |        6 7 8
    #  |
    #  |.............
    #  |
    #  |1           2
    #  --------------
    #
    # @param matrixVar reference to the datamatrix (list of lists)
    # @param val byte to place
    #
    proc corner4 { matrixVar val } {
        upvar $matrixVar matrix

        set numrows [llength $matrix]
        set numcols [llength $matrix]

        module matrix $numrows-1 0 $val 1
        module matrix $numrows-1 $numcols-1 $val 2
        module matrix 0 $numcols-3 $val 3
        module matrix 0 $numcols-2 $val 4
        module matrix 0 $numcols-1 $val 5
        module matrix 1 $numcols-3 $val 6
        module matrix 1 $numcols-2 $val 7
        module matrix 1 $numcols-1 $val 8
    }
}
