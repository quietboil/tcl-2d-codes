##
# QR Code demo
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

package require qrcode

##
# Displays a panel with QR Code in it.
#
# @param text data to put into the QR Code
# @param args optional pairs of additional arguments:
#   -eclevel L|M|Q|H - required error correction level, where:
#       L -  7% : dirt-free environments
#       M - 15% : most common
#       Q - 25% : factory environments where
#       H - 30% : label is subject to wear and tear.
#       If eclevel is not specified, L will be used (displays are considered a
#       dirt-free environment).
#   -ppm <num-pixels> - size of the module in pixels. If ppm is not specified, it
#       will be automatically selected using the built-in heuristic.
#   -window top level window where to display the matrix. Defaults to .qrcode
#
# @note This procedure automatically selects the most appropriate QR version
#       and encoding for the provided text.
#
# @note Depending on the available remaining space the error correction level
#       might be automatically elevated.
#
proc displayQRCode { text args } {
    if { [catch {dict get $args -window} window] } {
        set window .qrcode
    }
    if { [catch {dict get $args -eclevel} eclevel] } {
        set eclevel L
    }
    if { $eclevel ni {L M Q H} } {
        return -code error "-eclevel must be one of L, M, Q or H"
    }
    if { [catch {dict get $args -ppm} ppm] } {
        set ppm 0
    }
    displayQRMatrix $window [::qrcode::make $text -eclevel $eclevel] $ppm 
}

##
# Displays a panel with QR Code in it.
#
# @param window top leve window where the matrix will be displayed
# @param modules matrix of QR bits (returned by `make`)
# @param ppm size of the module in pixels
#
proc displayQRMatrix { window modules ppm } {
    set dim [llength $modules]

    if { $ppm == 0 } {
        set ppm [expr {
            $dim <=  33 ? 8 :
            $dim <=  45 ? 7 :
            $dim <=  57 ? 6 :
            $dim <=  69 ? 5 :
            $dim <=  89 ? 4 :
            $dim <= 117 ? 3 : 2
        }]
    }
    set size [expr ($dim + 8) * $ppm ]

    # Build up the display
    if { ![winfo exists $window] } {
        toplevel $window
        wm protocol $window WM_DELETE_WINDOW [list destroy $window]
    }
    wm title $window "QR Code"
    
    if { $window == {.} } {
        set base {}
    } else {
        set base $window
    }
    
    if { [winfo exists $base.img] } {
        $base.img delete all
        $base.img configure -width $size -height $size
    } else {

        canvas $base.img -width $size -height $size -background white

        grid $base.img   -in $window -row 1 -column 1
        grid columnconfigure $window 1 -minsize $size -weight 1
        grid rowconfigure    $window 1 -minsize $size -weight 1
    }

    # Paint the modules
    set y        [expr $ppm * 4  ]
    set nextRowY [expr $y + $ppm ]
    foreach row $modules {
        set x        [expr $ppm * 4  ]
        set nextColX [expr $x + $ppm ]

        foreach module $row {
            if { $module == 1 } {
                $base.img create rectangle $x $y $nextColX $nextRowY -fill black
            }
            set x $nextColX
            incr nextColX $ppm
        }
        set y $nextRowY
        incr nextRowY $ppm
    }
}

displayQRCode {*}$argv

