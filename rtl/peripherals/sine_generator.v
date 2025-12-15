/**
 * @file sine_generator.v
 * @brief Sine Wave Generator using LUT with Phase Accumulator
 *
 * Generates a sinusoidal reference waveform using a 256-entry lookup table.
 * The phase accumulator provides smooth frequency control.
 *
 * Features:
 * - 256-entry sine LUT (quarter-wave symmetry)
 * - 32-bit phase accumulator for fine frequency resolution
 * - Programmable modulation index (amplitude scaling)
 * - Outputs signed 16-bit sine value
 *
 * Frequency calculation:
 *   f_out = (freq_increment * f_clk) / 2^32
 *
 * For 50 Hz @ 50 MHz:
 *   freq_increment = (50 * 2^32) / 50e6 = 4295 (approx)
 *
 * @author RISC-V SoC Team
 * @date 2025-12-13
 */

module sine_generator #(
    parameter DATA_WIDTH = 16,
    parameter PHASE_WIDTH = 32,
    parameter LUT_ADDR_WIDTH = 8
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         enable,
    input  wire [PHASE_WIDTH-1:0]       freq_increment,    // Phase increment per clock
    input  wire [15:0]                  modulation_index,  // 0-65535 = 0.0-1.0

    output reg signed [DATA_WIDTH-1:0]  sine_out,
    output wire [PHASE_WIDTH-1:0]       phase             // Current phase (for debug)
);

    //==========================================================================
    // Phase Accumulator
    //==========================================================================

    reg [PHASE_WIDTH-1:0] phase_acc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= 0;
        end else if (enable) begin
            phase_acc <= phase_acc + freq_increment;
        end
    end

    assign phase = phase_acc;

    //==========================================================================
    // Sine Lookup Table (256 entries, quarter-wave)
    //==========================================================================

    // Use top 8 bits of phase as LUT address
    wire [7:0] lut_addr = phase_acc[PHASE_WIDTH-1:PHASE_WIDTH-8];

    // Quarter-wave sine LUT (0 to 90 degrees)
    // Values are normalized to ±32767 (signed 16-bit)
    reg signed [15:0] sine_lut [0:255];

    // Initialize sine LUT
    initial begin
        // Quarter wave (0° to 90°): indices 0-63
        sine_lut[0]   = 16'sd0;      sine_lut[1]   = 16'sd804;    sine_lut[2]   = 16'sd1608;   sine_lut[3]   = 16'sd2410;
        sine_lut[4]   = 16'sd3212;   sine_lut[5]   = 16'sd4011;   sine_lut[6]   = 16'sd4808;   sine_lut[7]   = 16'sd5602;
        sine_lut[8]   = 16'sd6393;   sine_lut[9]   = 16'sd7179;   sine_lut[10]  = 16'sd7962;   sine_lut[11]  = 16'sd8739;
        sine_lut[12]  = 16'sd9512;   sine_lut[13]  = 16'sd10278;  sine_lut[14]  = 16'sd11039;  sine_lut[15]  = 16'sd11793;
        sine_lut[16]  = 16'sd12539;  sine_lut[17]  = 16'sd13279;  sine_lut[18]  = 16'sd14010;  sine_lut[19]  = 16'sd14732;
        sine_lut[20]  = 16'sd15446;  sine_lut[21]  = 16'sd16151;  sine_lut[22]  = 16'sd16846;  sine_lut[23]  = 16'sd17530;
        sine_lut[24]  = 16'sd18204;  sine_lut[25]  = 16'sd18868;  sine_lut[26]  = 16'sd19519;  sine_lut[27]  = 16'sd20159;
        sine_lut[28]  = 16'sd20787;  sine_lut[29]  = 16'sd21403;  sine_lut[30]  = 16'sd22005;  sine_lut[31]  = 16'sd22594;
        sine_lut[32]  = 16'sd23170;  sine_lut[33]  = 16'sd23731;  sine_lut[34]  = 16'sd24279;  sine_lut[35]  = 16'sd24811;
        sine_lut[36]  = 16'sd25329;  sine_lut[37]  = 16'sd25832;  sine_lut[38]  = 16'sd26319;  sine_lut[39]  = 16'sd26790;
        sine_lut[40]  = 16'sd27245;  sine_lut[41]  = 16'sd27683;  sine_lut[42]  = 16'sd28105;  sine_lut[43]  = 16'sd28510;
        sine_lut[44]  = 16'sd28898;  sine_lut[45]  = 16'sd29268;  sine_lut[46]  = 16'sd29621;  sine_lut[47]  = 16'sd29956;
        sine_lut[48]  = 16'sd30273;  sine_lut[49]  = 16'sd30571;  sine_lut[50]  = 16'sd30852;  sine_lut[51]  = 16'sd31113;
        sine_lut[52]  = 16'sd31356;  sine_lut[53]  = 16'sd31580;  sine_lut[54]  = 16'sd31785;  sine_lut[55]  = 16'sd31971;
        sine_lut[56]  = 16'sd32137;  sine_lut[57]  = 16'sd32285;  sine_lut[58]  = 16'sd32412;  sine_lut[59]  = 16'sd32521;
        sine_lut[60]  = 16'sd32609;  sine_lut[61]  = 16'sd32678;  sine_lut[62]  = 16'sd32728;  sine_lut[63]  = 16'sd32757;

        // Second quarter (90° to 180°): mirror of first quarter
        sine_lut[64]  = 16'sd32767;  sine_lut[65]  = 16'sd32757;  sine_lut[66]  = 16'sd32728;  sine_lut[67]  = 16'sd32678;
        sine_lut[68]  = 16'sd32609;  sine_lut[69]  = 16'sd32521;  sine_lut[70]  = 16'sd32412;  sine_lut[71]  = 16'sd32285;
        sine_lut[72]  = 16'sd32137;  sine_lut[73]  = 16'sd31971;  sine_lut[74]  = 16'sd31785;  sine_lut[75]  = 16'sd31580;
        sine_lut[76]  = 16'sd31356;  sine_lut[77]  = 16'sd31113;  sine_lut[78]  = 16'sd30852;  sine_lut[79]  = 16'sd30571;
        sine_lut[80]  = 16'sd30273;  sine_lut[81]  = 16'sd29956;  sine_lut[82]  = 16'sd29621;  sine_lut[83]  = 16'sd29268;
        sine_lut[84]  = 16'sd28898;  sine_lut[85]  = 16'sd28510;  sine_lut[86]  = 16'sd28105;  sine_lut[87]  = 16'sd27683;
        sine_lut[88]  = 16'sd27245;  sine_lut[89]  = 16'sd26790;  sine_lut[90]  = 16'sd26319;  sine_lut[91]  = 16'sd25832;
        sine_lut[92]  = 16'sd25329;  sine_lut[93]  = 16'sd24811;  sine_lut[94]  = 16'sd24279;  sine_lut[95]  = 16'sd23731;
        sine_lut[96]  = 16'sd23170;  sine_lut[97]  = 16'sd22594;  sine_lut[98]  = 16'sd22005;  sine_lut[99]  = 16'sd21403;
        sine_lut[100] = 16'sd20787;  sine_lut[101] = 16'sd20159;  sine_lut[102] = 16'sd19519;  sine_lut[103] = 16'sd18868;
        sine_lut[104] = 16'sd18204;  sine_lut[105] = 16'sd17530;  sine_lut[106] = 16'sd16846;  sine_lut[107] = 16'sd16151;
        sine_lut[108] = 16'sd15446;  sine_lut[109] = 16'sd14732;  sine_lut[110] = 16'sd14010;  sine_lut[111] = 16'sd13279;
        sine_lut[112] = 16'sd12539;  sine_lut[113] = 16'sd11793;  sine_lut[114] = 16'sd11039;  sine_lut[115] = 16'sd10278;
        sine_lut[116] = 16'sd9512;   sine_lut[117] = 16'sd8739;   sine_lut[118] = 16'sd7962;   sine_lut[119] = 16'sd7179;
        sine_lut[120] = 16'sd6393;   sine_lut[121] = 16'sd5602;   sine_lut[122] = 16'sd4808;   sine_lut[123] = 16'sd4011;
        sine_lut[124] = 16'sd3212;   sine_lut[125] = 16'sd2410;   sine_lut[126] = 16'sd1608;   sine_lut[127] = 16'sd804;

        // Third quarter (180° to 270°): negative of first quarter
        sine_lut[128] = 16'sd0;      sine_lut[129] = -16'sd804;   sine_lut[130] = -16'sd1608;  sine_lut[131] = -16'sd2410;
        sine_lut[132] = -16'sd3212;  sine_lut[133] = -16'sd4011;  sine_lut[134] = -16'sd4808;  sine_lut[135] = -16'sd5602;
        sine_lut[136] = -16'sd6393;  sine_lut[137] = -16'sd7179;  sine_lut[138] = -16'sd7962;  sine_lut[139] = -16'sd8739;
        sine_lut[140] = -16'sd9512;  sine_lut[141] = -16'sd10278; sine_lut[142] = -16'sd11039; sine_lut[143] = -16'sd11793;
        sine_lut[144] = -16'sd12539; sine_lut[145] = -16'sd13279; sine_lut[146] = -16'sd14010; sine_lut[147] = -16'sd14732;
        sine_lut[148] = -16'sd15446; sine_lut[149] = -16'sd16151; sine_lut[150] = -16'sd16846; sine_lut[151] = -16'sd17530;
        sine_lut[152] = -16'sd18204; sine_lut[153] = -16'sd18868; sine_lut[154] = -16'sd19519; sine_lut[155] = -16'sd20159;
        sine_lut[156] = -16'sd20787; sine_lut[157] = -16'sd21403; sine_lut[158] = -16'sd22005; sine_lut[159] = -16'sd22594;
        sine_lut[160] = -16'sd23170; sine_lut[161] = -16'sd23731; sine_lut[162] = -16'sd24279; sine_lut[163] = -16'sd24811;
        sine_lut[164] = -16'sd25329; sine_lut[165] = -16'sd25832; sine_lut[166] = -16'sd26319; sine_lut[167] = -16'sd26790;
        sine_lut[168] = -16'sd27245; sine_lut[169] = -16'sd27683; sine_lut[170] = -16'sd28105; sine_lut[171] = -16'sd28510;
        sine_lut[172] = -16'sd28898; sine_lut[173] = -16'sd29268; sine_lut[174] = -16'sd29621; sine_lut[175] = -16'sd29956;
        sine_lut[176] = -16'sd30273; sine_lut[177] = -16'sd30571; sine_lut[178] = -16'sd30852; sine_lut[179] = -16'sd31113;
        sine_lut[180] = -16'sd31356; sine_lut[181] = -16'sd31580; sine_lut[182] = -16'sd31785; sine_lut[183] = -16'sd31971;
        sine_lut[184] = -16'sd32137; sine_lut[185] = -16'sd32285; sine_lut[186] = -16'sd32412; sine_lut[187] = -16'sd32521;
        sine_lut[188] = -16'sd32609; sine_lut[189] = -16'sd32678; sine_lut[190] = -16'sd32728; sine_lut[191] = -16'sd32757;

        // Fourth quarter (270° to 360°): negative mirror of first quarter
        sine_lut[192] = -16'sd32767; sine_lut[193] = -16'sd32757; sine_lut[194] = -16'sd32728; sine_lut[195] = -16'sd32678;
        sine_lut[196] = -16'sd32609; sine_lut[197] = -16'sd32521; sine_lut[198] = -16'sd32412; sine_lut[199] = -16'sd32285;
        sine_lut[200] = -16'sd32137; sine_lut[201] = -16'sd31971; sine_lut[202] = -16'sd31785; sine_lut[203] = -16'sd31580;
        sine_lut[204] = -16'sd31356; sine_lut[205] = -16'sd31113; sine_lut[206] = -16'sd30852; sine_lut[207] = -16'sd30571;
        sine_lut[208] = -16'sd30273; sine_lut[209] = -16'sd29956; sine_lut[210] = -16'sd29621; sine_lut[211] = -16'sd29268;
        sine_lut[212] = -16'sd28898; sine_lut[213] = -16'sd28510; sine_lut[214] = -16'sd28105; sine_lut[215] = -16'sd27683;
        sine_lut[216] = -16'sd27245; sine_lut[217] = -16'sd26790; sine_lut[218] = -16'sd26319; sine_lut[219] = -16'sd25832;
        sine_lut[220] = -16'sd25329; sine_lut[221] = -16'sd24811; sine_lut[222] = -16'sd24279; sine_lut[223] = -16'sd23731;
        sine_lut[224] = -16'sd23170; sine_lut[225] = -16'sd22594; sine_lut[226] = -16'sd22005; sine_lut[227] = -16'sd21403;
        sine_lut[228] = -16'sd20787; sine_lut[229] = -16'sd20159; sine_lut[230] = -16'sd19519; sine_lut[231] = -16'sd18868;
        sine_lut[232] = -16'sd18204; sine_lut[233] = -16'sd17530; sine_lut[234] = -16'sd16846; sine_lut[235] = -16'sd16151;
        sine_lut[236] = -16'sd15446; sine_lut[237] = -16'sd14732; sine_lut[238] = -16'sd14010; sine_lut[239] = -16'sd13279;
        sine_lut[240] = -16'sd12539; sine_lut[241] = -16'sd11793; sine_lut[242] = -16'sd11039; sine_lut[243] = -16'sd10278;
        sine_lut[244] = -16'sd9512;  sine_lut[245] = -16'sd8739;  sine_lut[246] = -16'sd7962;  sine_lut[247] = -16'sd7179;
        sine_lut[248] = -16'sd6393;  sine_lut[249] = -16'sd5602;  sine_lut[250] = -16'sd4808;  sine_lut[251] = -16'sd4011;
        sine_lut[252] = -16'sd3212;  sine_lut[253] = -16'sd2410;  sine_lut[254] = -16'sd1608;  sine_lut[255] = -16'sd804;
    end

    //==========================================================================
    // LUT Readout and Amplitude Scaling
    //==========================================================================

    wire signed [15:0] sine_raw = sine_lut[lut_addr];

    // Multiply by modulation index (fixed-point: modulation_index / 65536)
    // Result: sine_raw * (modulation_index / 65536)
    wire signed [31:0] sine_scaled = sine_raw * $signed({1'b0, modulation_index});

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sine_out <= 0;
        end else begin
            // Take upper 16 bits of the 32-bit result (effectively divide by 65536)
            sine_out <= sine_scaled[31:16];
        end
    end

endmodule
