// Arquivo: simulacao_completa_decimal.v
// Contém TODOS os módulos necessários (testbench, processador, etc.)

//-----------------------------------------------------------------
// Módulo 1: Bancada de Teste (Testbench)
//-----------------------------------------------------------------
module bancada_de_teste;
    reg clk;
    reg rst;

    // Instancia o processador
    processador_riscv dut (
        .clk(clk),
        .rst(rst)
    );

    // Gera o clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Sequencia da simulacao
    initial begin
        rst = 1;
        #10;
        rst = 0;
        
        // Inicializa a memória de dados com zeros para evitar 'x' na saída
        for (integer j = 0; j < 64; j = j + 1) begin
            dut.memoria_dados[j] = 32'h00000000;
        end
        
        #200; // Roda por tempo suficiente

        // Imprime os resultados
        $display("--- Estado Final dos Registradores (em Decimal) ---");
        for (integer i = 0; i < 32; i = i + 1) begin
            // O '$signed' garante a interpretação correta de números negativos.
            $display("Registrador[%2d]: %d", i, $signed(dut.regs.registradores[i]));
        end

        $display("\n--- Estado Final da Memoria de Dados (em Decimal) ---");
        for (integer i = 0; i < 8; i = i + 1) begin
             $display("Memoria[%d]: %d", i*4, $signed(dut.memoria_dados[i]));
        end
        $finish;
    end
endmodule

//-----------------------------------------------------------------
// Módulo 2: Processador RISC-V (Top Level)
//-----------------------------------------------------------------
module processador_riscv(
    input clk,
    input rst
);
    // Sinais de Controle
    wire escreve_reg, mem_para_reg, le_mem, escreve_mem, desvio_beq, desvio_bne, ula_src;
    wire [1:0] op_ula;
    wire [3:0] controle_ula;

    // Sinais do Caminho de Dados
    reg [31:0] pc;
    wire [31:0] instrucao;
    wire [31:0] dado_leitura1, dado_leitura2, dado_escrita_reg;
    wire [31:0] imediato, operando_b_ula, resultado_ula;
    wire [31:0] dado_lido_memoria, dado_lido_memoria_estendido;
    wire flag_zero, tomar_desvio;

    // Memorias
    reg [31:0] memoria_instrucoes [0:63];
    reg [31:0] memoria_dados [0:63];

    // --- Lógica do Caminho de Dados ---

    // 1. Busca da Instrução
    assign instrucao = memoria_instrucoes[pc >> 2];

    // 2. Lógica do PC
    assign tomar_desvio = (desvio_beq & flag_zero) | (desvio_bne & ~flag_zero);
    always @(posedge clk or posedge rst) begin
        if (rst)
            pc <= 32'h0;
        else
            pc <= tomar_desvio ? (pc + imediato) : (pc + 4);
    end

    // 3. Decodificacao e Banco de Registradores
    unidade_de_controle ctrl (.opcode(instrucao[6:0]), .funct3(instrucao[14:12]), .escreve_reg(escreve_reg), .mem_para_reg(mem_para_reg), .le_mem(le_mem), .escreve_mem(escreve_mem), .desvio_beq(desvio_beq), .desvio_bne(desvio_bne), .ula_src(ula_src), .op_ula(op_ula));
    banco_de_registradores regs (.clk(clk), .rst(rst), .escreve_reg(escreve_reg), .end_leitura1(instrucao[19:15]), .end_leitura2(instrucao[24:20]), .end_escrita(instrucao[11:7]), .dado_escrita(dado_escrita_reg), .dado_leitura1(dado_leitura1), .dado_leitura2(dado_leitura2));
    gerador_de_imediatos gerador_imm (.instrucao(instrucao), .imediato(imediato));

    // 4. Execucao (ULA)
    assign operando_b_ula = ula_src ? imediato : dado_leitura2;
    controle_da_ula ctrl_ula (.op_ula(op_ula), .funct3(instrucao[14:12]), .funct7(instrucao[30]), .saida_controle_ula(controle_ula));
    ula minha_ula (.a(dado_leitura1), .b(operando_b_ula), .controle_ula(controle_ula), .resultado(resultado_ula), .zero(flag_zero));

    // 5. Acesso a Memoria
    always @(posedge clk) begin
        if (escreve_mem) begin
            if (instrucao[14:12] == 3'b001) // sh
                memoria_dados[resultado_ula >> 2][15:0] <= dado_leitura2[15:0];
        end
    end
    assign dado_lido_memoria = memoria_dados[resultado_ula >> 2];
    assign dado_lido_memoria_estendido = (le_mem && instrucao[14:12]==3'b001) ? {{16{dado_lido_memoria[15]}}, dado_lido_memoria[15:0]} : dado_lido_memoria;

    // 6. Write-Back
    assign dado_escrita_reg = mem_para_reg ? dado_lido_memoria_estendido : resultado_ula;

    // Carrega os arquivos na memoria para simulacao
    initial begin
        $readmemh("codigo_binario.txt", memoria_instrucoes);
        $readmemh("estado_inicial_memoria_dados.txt", memoria_dados);
    end
endmodule

//-----------------------------------------------------------------
// Módulo 3: Unidade de Controle Principal
//-----------------------------------------------------------------
module unidade_de_controle(
    input [6:0] opcode,
    input [2:0] funct3,
    output reg escreve_reg,
    output reg mem_para_reg,
    output reg le_mem,
    output reg escreve_mem,
    output reg desvio_beq,
    output reg desvio_bne,
    output reg ula_src,
    output reg [1:0] op_ula
);
    localparam OP_RTYPE=7'b0110011, OP_ITYPE=7'b0010011, OP_LOAD=7'b0000011, OP_STORE=7'b0100011, OP_BRANCH=7'b1100011;
    
    always @(*) begin
        escreve_reg=0; mem_para_reg=0; le_mem=0; escreve_mem=0; desvio_beq=0; desvio_bne=0; ula_src=0; op_ula=2'bxx; // Padrão 'Não importa'
        case (opcode)
            OP_RTYPE:   begin escreve_reg=1; ula_src=0; op_ula=2'b10; end // Tipo-R usa funct
            OP_ITYPE:   begin escreve_reg=1; ula_src=1; op_ula=2'b00; end // I-Type ALU
            OP_LOAD:    begin escreve_reg=1; le_mem=1; mem_para_reg=1; ula_src=1; op_ula=2'b01; end // Load (Soma)
            OP_STORE:   begin escreve_mem=1; ula_src=1; op_ula=2'b01; end // Store (Soma)
            OP_BRANCH:  begin op_ula=2'b11; if (funct3 == 3'b001) desvio_bne=1; else desvio_beq=1; end // Branch (Sub)
        endcase
    end
endmodule

//-----------------------------------------------------------------
// Módulo 4: Controle da ULA
//-----------------------------------------------------------------
module controle_da_ula(
    input [1:0] op_ula,
    input [2:0] funct3,
    input funct7,
    output reg [3:0] saida_controle_ula
);
    localparam ULA_SOMA=4'b0000, ULA_SUB=4'b0001, ULA_E=4'b0010, ULA_OU=4'b0011, ULA_SLL=4'b0100;
    
    always @(*) begin
        case (op_ula)
            2'b00: // I-Type ALU (andi, slli)
                case (funct3)
                    3'b001: saida_controle_ula = ULA_SLL; // SLLI
                    3'b111: saida_controle_ula = ULA_E;   // ANDI
                    default: saida_controle_ula = ULA_SOMA; // ADDI
                endcase
            2'b01: // Load/Store
                saida_controle_ula = ULA_SOMA;
            2'b10: // Tipo-R (add, or)
                case (funct3)
                    3'b000: saida_controle_ula = ULA_SOMA; // ADD
                    3'b110: saida_controle_ula = ULA_OU;   // OR
                    default: saida_controle_ula = 4'bxxxx;
                endcase
            2'b11: // Branch
                saida_controle_ula = ULA_SUB;
            default: saida_controle_ula = 4'bxxxx;
        endcase
    end
endmodule

//-----------------------------------------------------------------
// Módulo 5: ULA (Unidade Lógica e Aritmética)
//-----------------------------------------------------------------
module ula(
    input [31:0] a,
    input [31:0] b,
    input [3:0]  controle_ula,
    output reg [31:0] resultado,
    output zero
);
    localparam ULA_SOMA=4'b0000, ULA_SUB=4'b0001, ULA_E=4'b0010, ULA_OU=4'b0011, ULA_SLL=4'b0100;

    always @(*) case (controle_ula)
        ULA_SOMA: resultado = a + b;
        ULA_SUB:  resultado = a - b;
        ULA_E:    resultado = a & b;
        ULA_OU:   resultado = a | b;
        ULA_SLL:  resultado = a << b[4:0];
        default:  resultado = 32'hdeadbeef;
    endcase
    assign zero = (resultado == 32'b0);
endmodule

//-----------------------------------------------------------------
// Módulo 6: Banco de Registradores
//-----------------------------------------------------------------
module banco_de_registradores(
    input clk, input rst, input escreve_reg,
    input [4:0] end_leitura1, input [4:0] end_leitura2,
    input [4:0] end_escrita, input [31:0] dado_escrita,
    output [31:0] dado_leitura1, output [31:0] dado_leitura2
);
    reg [31:0] registradores [0:31];
    integer i;

    always @(posedge clk) if (escreve_reg && (end_escrita != 5'b0)) registradores[end_escrita] <= dado_escrita;

    assign dado_leitura1 = (end_leitura1 == 5'b0) ? 32'b0 : registradores[end_leitura1];
    assign dado_leitura2 = (end_leitura2 == 5'b0) ? 32'b0 : registradores[end_leitura2];

    initial for (i=0; i<32; i=i+1) registradores[i]=32'b0;
endmodule

//-----------------------------------------------------------------
// Módulo 7: Gerador de Imediatos
//-----------------------------------------------------------------
module gerador_de_imediatos(
    input [31:0] instrucao,
    output [31:0] imediato
);
    wire [6:0] opcode = instrucao[6:0];
    localparam OP_ITYPE=7'b0010011, OP_LOAD=7'b0000011, OP_STORE=7'b0100011, OP_BRANCH=7'b1100011;

    assign imediato =
        (opcode==OP_LOAD || opcode==OP_ITYPE) ? {{20{instrucao[31]}}, instrucao[31:20]} :
        (opcode==OP_STORE)                 ? {{20{instrucao[31]}}, instrucao[31:25], instrucao[11:7]} :
        (opcode==OP_BRANCH)                ? {{20{instrucao[31]}}, instrucao[7], instrucao[30:25], instrucao[11:8], 1'b0} :
        32'hdeadbeef;
endmodule
