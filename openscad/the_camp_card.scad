// THE CÄMP 2026 - Badge mit TYPO3-Logo
// Maße: 100 x 60 mm

// DEBUG ========
debug_logo = false;
debug_section = false;            // Querschnitt-Ansicht
debug_section_y = 30;             // Schnitt-Position (Y-Achse)

// PARAMETER (für CSV-Import) ========
vorname = "Max";
nachname = "Mustermann";
firma = "Beispiel GmbH";

// BADGE EINSTELLUNGEN ========
badge_width = 100;
badge_height = 60;
badge_thickness = 1.4;
corner_radius = 6;
$fn = 100;                  

// LOCH ========
hole_diameter = 8;
hole_margin = 6;

// FARBEN ========
color_base = "#FFFC00";       // BaWü Gelb
color_accent = "#2A2623";     // BaWü Schwarz

// FONTS ========
font_name = "Onest:style=SemiBold";
font_logo = "Onest:style=ExtraBold";    // Google Font - muss installiert sein!  

// BASE VARS ========
extrude = 0.4;
text_x = 6.75;
name_size = 5.25;

// VORNAME ========
vorname_pos_x = text_x;
vorname_pos_y = 48;           // badge_height - 12
vorname_size = name_size;
vorname_height = extrude;

// NACHNAME ========
nachname_pos_x = text_x;
nachname_pos_y = vorname_pos_y - 7.25;          // unterhalb von vorname
nachname_size = name_size;
nachname_height = extrude;

// FIRMA ========
firma_pos_x = text_x;
firma_pos_y = nachname_pos_y - 7.25;             // angepasst, um Platz zu schaffen
firma_size = 3.5;
firma_height = extrude;
firma_max_chars = 20;                             // Umbruch ab dieser Zeichenanzahl
firma_line_spacing = 5.25;                        // Abstand zwischen Zeile 1 und 2

// STRING HELPERS ========
function _join(v, i=0) =
    i >= len(v) ? "" : str(v[i], _join(v, i+1));

function substr(s, start, end) =
    _join([for (i = [start:min(end, len(s))-1]) s[i]]);

function last_space(s, pos) =
    pos <= 0 ? pos :
    s[pos] == " " ? pos :
    last_space(s, pos - 1);

// Pipe "|" als Force-Trenner: splittet dort und entfernt das Pipe-Zeichen
function find_pipe(s, i=0) =
    i >= len(s) ? -1 :
    s[i] == "|" ? i :
    find_pipe(s, i + 1);

function trim_start(s) =
    len(s) > 0 && s[0] == " " ? substr(s, 1, len(s)) : s;

function trim_end(s) =
    len(s) > 0 && s[len(s)-1] == " " ? substr(s, 0, len(s)-1) : s;

function split_pipe(s) =
    let(p = find_pipe(s))
    p < 0 ? [s] :
    concat([trim_end(substr(s, 0, p))], split_pipe(trim_start(substr(s, p + 1, len(s)))));

// FIRMA WRAPPING (rekursiv, beliebig viele Zeilen) ========
function wrap_lines(s, max) =
    len(s) <= max ? [s] :
    let(bp = last_space(s, max))
    bp <= 0 ? [s] :
    concat([substr(s, 0, bp)], wrap_lines(substr(s, bp + 1, len(s)), max));

// Erst an Pipes splitten, dann jedes Segment bei Bedarf umbrechen
function wrap_all(segments, max, i=0) =
    i >= len(segments) ? [] :
    concat(wrap_lines(segments[i], max), wrap_all(segments, max, i + 1));

firma_lines = wrap_all(split_pipe(firma), firma_max_chars);

// THE CÄMP ========
camp_pos_x = text_x;
camp_pos_y = 8;
camp_size = 7;
camp_height = extrude;

// TYPO3 LOGO ========
logo_scale = 0.7;
logo_pos_x = 57;
logo_pos_y = -20.75;
logo_height = extrude + 0.2;  

// 2026 ========
year_pos_x = 76.3;              // badge_width - 18
year_pos_y = camp_pos_y;
year_size = camp_size;
year_height = logo_height;

          // Gleiche Höhe wie Schrift

// HAUPTMODUL ========
module badge() {
    difference() {
        union() {
            // Basis-Platte
            color(color_base)
                base_plate();

            // Vorname
            color(color_accent)
                translate([vorname_pos_x, vorname_pos_y, badge_thickness])
                    linear_extrude(vorname_height)
                        text(vorname, size = vorname_size, font = font_name, halign = "left");

            // Nachname
            color(color_accent)
                translate([nachname_pos_x, nachname_pos_y, badge_thickness])
                    linear_extrude(nachname_height)
                        text(nachname, size = nachname_size, font = font_name, halign = "left");

            // Firma (mehrzeilig)
            for (i = [0:len(firma_lines)-1])
                color(color_accent)
                    translate([firma_pos_x, firma_pos_y - i * firma_line_spacing, badge_thickness])
                        linear_extrude(firma_height)
                            text(firma_lines[i], size = firma_size, font = font_name, halign = "left");

            // THE CÄMP
            color(color_accent)
                translate([camp_pos_x, camp_pos_y, badge_thickness])
                    linear_extrude(camp_height)
                        text("THE CÄMP", size = camp_size, font = font_logo, halign = "left");

            // TYPO3 Logo
            color(color_accent)
                translate([0, 0, badge_thickness])
                    typo3_logo();
        }

        // Loch oben rechts
        translate([badge_width - hole_margin, badge_height - hole_margin, -1])
            cylinder(h = badge_thickness + 5, d = hole_diameter, $fn = 32);

        // 2026 als Vertiefung ins Logo
        translate([year_pos_x, year_pos_y, badge_thickness + logo_height - year_height + 0.01])
            linear_extrude(year_height + 1)
                text("2026", size = year_size, font = font_logo, halign = "center");

    }
}

// KOMPONENTEN ============

module base_plate() {
    linear_extrude(badge_thickness)
        offset(r = corner_radius)
            offset(r = -corner_radius)
                square([badge_width, badge_height]);
}

module typo3_logo() {
    if (debug_logo) {
        // DEBUG: Logo ohne Beschneidung
        color("red", 0.5)
            linear_extrude(logo_height)
                translate([logo_pos_x, logo_pos_y])
                    scale([logo_scale, logo_scale])
                        import("typo3_logo.svg", center = false);

        // Badge-Umriss
        color("blue", 0.3)
            linear_extrude(0.1)
                offset(r = corner_radius)
                    offset(r = -corner_radius)
                        square([badge_width, badge_height]);
    } else {
        // NORMAL: Logo mit Beschneidung
        linear_extrude(logo_height)
            intersection() {
                offset(r = corner_radius)
                    offset(r = -corner_radius)
                        square([badge_width, badge_height]);

                translate([logo_pos_x, logo_pos_y])
                    scale([logo_scale, logo_scale])
                        import("typo3_logo.svg", center = false);
            }
    }
}

// RENDER ============
if (debug_section) {
    difference() {
        badge();
        // Schneidet alles oberhalb von debug_section_y ab
        translate([-10, debug_section_y, -1])
            cube([badge_width + 20, badge_height, badge_thickness + 10]);
    }
} else {
    badge();
}