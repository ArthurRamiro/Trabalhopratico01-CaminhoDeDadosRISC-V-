# Objetivo: Validar as instruções lh, sh, add, or, andi, sll, bne.

# lh -> Carrega uma meia palavra. Lê 16 bits(meia palavra) da memória e coloca em um registrador de 32 bits.
# sh -> Guarda meia palavra. Pega os 16 bits inferiores de um registrador e escreve na memória.

# add -> "Soma" o valor de registradores e guarda o resultado em um outro registrador dentro da ULA(Unid. Lógica e Artitmética).
# or ->  "OU". Compara os bits de dois registradores.
# andi -> Operação lógica "E" com um valor constante (imediato). Para "isolar" ou "mascarar" bits.
# sll ->  "Deslocamento Lógico para a Esquerda". Maneira rápida de multiplicar por potências de 2. 
# Deslocar 1 bit para a esquerda é o mesmo que multiplicar por 2. Deslocar 2 bits para a esquerda é o mesmo que multiplicar por 4.

# bne -> "Salta se Não for Igual". É uma instrução condicional.

# --- Bloco de Inicializacao --- Carrega valores nos registradores usando ANDI e SLL.

addi x5, x0, 10      # x5 = 10
addi x6, x0, -3      # x6 = -3 (valor 0xFFFFFFFD)
slli x7, x5, 2       # x7 = 10 << 2 = 40 (valor 0x28)

# --- Teste de Memoria --- Guarda e carrega um valor para testar SH, LH e o cálculo de endereço.

sh x6, 8(x0)         # Memoria[8] = -3 Testa se SH e o cálculo de endereço 8(x0) funcionam.
lh x10, 8(x0)        # x10 = Memoria[8]. Carrega o valor de volta. Testa se LH e a EXTENSÃO DE SINAL funcionam.

# --- Testes Logicos e Aritmeticos --- Usa os valores carregados para testar ADD e OR.

add x11, x5, x7      # x11 = 10 + 40 = 50 (Testa ADD)
or x12, x5, x6       # x12 = 10 | -3 = -1 (Testa OR)

# --- Teste de Desvio --- Se LH funcionou, x10 e x6 devem ser iguais. Contendo -3.

# Portanto, o desvio BNE (Branch if Not Equal) para a rotina de ERRO NAO deve ser acontecer.

bne x10, x6, ERRO # Testa BNE. Se desviar, o processador está errado.

# --- Fluxo Correto ---

# Se o codigo chega aqui se o BNE funcionou corretamente.
# Pula incondicionalmente sobre o bloco de erro para o final do programa.
beq x0, x0, FIM      # Salto para FIM (offset de +8 bytes)

# --- Bloco de Erro (nao deve ser executado) ---

ERRO:
# Se o desvio foi tomado, coloca 1 em x2 para indicar o erro.
addi x2, x0, 1

# --- Fim da Execucao ---

FIM:
# Loop infinito para garantir que o processador pare aqui.
beq x0, x0, FIM
    
