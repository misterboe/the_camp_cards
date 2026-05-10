// THE CÄMP 2026 - Blanko-Badge ohne Name und Firma
// Maße: 100 x 60 mm

// DEBUG ========
debug_logo = false;
debug_section = false;            // Querschnitt-Ansicht
debug_section_y = 30;             // Schnitt-Position (Y-Achse)

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
font_logo = "Onest:style=ExtraBold";    // Google Font - muss installiert sein!

// BASE VARS ========
extrude = 0.4;
text_x = 6.75;

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

// HAUPTMODUL ========
module badge() {
    difference() {
        union() {
            // Basis-Platte
            color(color_base)
                base_plate();

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
