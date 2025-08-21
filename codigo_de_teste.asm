# Arquivo: codigo_de_teste.asm
# Nota: As duas primeiras instrucoes sao ADDI, nao ANDI, para corresponder ao binario.

# --- Bloco de Inicializacao ---
addi x5, x0, 10      # x5 = 10
addi x6, x0, -3      # x6 = -3 (valor 0xFFFFFFFD)
slli x7, x5, 2       # x7 = 10 << 2 = 40 (valor 0x28)

# --- Teste de Memoria ---
sh x6, 8(x0)         # Memoria[8] = -3 (armazena apenas os 16 bits inferiores: 0xFFFD)
lh x10, 8(x0)        # x10 = Memoria[8]. Carrega 0xFFFD e estende o sinal para 0xFFFFFFFD (-3)

# --- Testes Logicos e Aritmeticos ---
add x11, x5, x7      # x11 = 10 + 40 = 50 (valor 0x32)
or x12, x5, x6       # x12 = 10 | -3 = -1 (valor 0xFFFFFFFF)

# --- Teste CRITICO de Desvio ---
# 'lh' carregou -3 em x10, e x6 ja contem -3. Eles devem ser iguais.
# Portanto, o desvio BNE (Branch if Not Equal) para a rotina de ERRO NAO deve ser tomado.
bne x10, x6, ERRO

# --- Fluxo Correto ---
# O codigo chega aqui se o BNE funcionou corretamente.
# Pula incondicionalmente sobre o bloco de erro para o final do programa.
beq x0, x0, FIM      # Salto para FIM (offset de +8 bytes)

# --- Bloco de Erro (nao deve ser executado) ---
ERRO:
# Se o desvio BNE foi tomado incorretamente, o codigo chega aqui.
# Coloca 1 em x2 para sinalizar visualmente o erro na saida.
addi x2, x0, 1

# --- Fim da Execucao ---
FIM:
# Loop infinito para garantir que o processador pare aqui.
beq x0, x0, FIM

