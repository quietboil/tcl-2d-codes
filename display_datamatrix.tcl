##
# Datamatrix demo
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

package require datamatrix

##
# Displays a panel with datamatrix in it
#
# @param text message to display as the datamatrix
# @param args optional pairs of additional arguments:
#   -ppm <num-pixels> - size of the module in pixels. Defaults to 4, i.e. each module is 4x4 pixels
#   -window top level window where to display the matrix. Defaults to .datamatrix
#
# @exception messsage has characters that are not representable in ISO-8859-1
# @exception message is too long to be placed even into the largest matrix
#
proc displayDatamatrix { text args } {
    if { [catch {dict get $args -ppm} ppm] } {
        set ppm 4
    }
    if { [catch {dict get $args -window} window] } {
        set window .datamatrix
    }

    set modules [::datamatrix::make $text]
    set matrixSize [llength $modules]
    # Extend quiet zone from the required 1 to 4 modules
    set imgSize [expr ($matrixSize + 8) * $ppm ]

    # Build up the display
    if { ![winfo exists $window] } {
        toplevel $window
        wm protocol $window WM_DELETE_WINDOW [list destroy $window]
    }
    wm title $window "DataMatrix"
    
    if { $window == {.} } {
        set base {}
    } else {
        set base $window
    }
        
    if { [winfo exists $base.img] } {
        $base.img delete all
        $base.img configure -width $imgSize -height $imgSize
    } else {   

        canvas $base.img -width $imgSize -height $imgSize -background white

        grid $base.img   -in $window -row 1 -column 1
        grid columnconfigure $window 1 -minsize $imgSize -weight 1
        grid rowconfigure    $window 1 -minsize $imgSize -weight 1
    }

    # Paint the modules
    set y        [expr { $ppm * 4 }]
    set nextRowY [expr { $y + $ppm }]
    foreach row $modules {
        set x        [expr { $ppm * 4 }]
        set nextColX [expr { $x + $ppm }]

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

displayDatamatrix {*}$argv

