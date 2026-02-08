# 📐 Estimativa de Público — Metodologia

## Visão Geral

O sistema **Estou Aqui** utiliza múltiplos métodos para estimar o número de participantes em movimentos sociais, combinando dados reais (check-ins) com modelos estatísticos.

## Métodos de Estimativa

### 1. Contagem de Check-ins com Fator Multiplicador

O método mais simples: multiplica o número de check-ins ativos por um fator que representa a proporção de pessoas que não usam o app.

$$E = C \times F$$

Onde:
- $E$ = Estimativa de participantes
- $C$ = Check-ins ativos
- $F$ = Fator multiplicador

#### Fatores Multiplicadores

| Check-ins ativos | Fator | Contexto |
|------------------|-------|----------|
| < 10             | 3×    | Evento pequeno, app bem divulgado |
| 10-49            | 5×    | Engajamento moderado |
| 50-199           | 8×    | Grande evento com boa adoção |
| 200-999          | 12×   | Manifestação grande |
| ≥ 1000           | 15×   | Grande manifestação de rua |

### 2. Método de Jacobs (Densidade × Área)

Baseado no trabalho de Herbert Jacobs (1967), este método estima o público pela densidade de ocupação de uma área conhecida.

$$E = A \times D$$

Onde:
- $A$ = Área em metros quadrados
- $D$ = Densidade (pessoas/m²)

#### Níveis de Densidade

| Nível       | Densidade (p/m²) | Descrição |
|-------------|-------------------|-----------|
| Baixa       | 0.5               | Pessoas espalhadas (parque, praça ampla) |
| Média       | 1.5               | Multidão moderada (rua, calçadão) |
| Alta         | 3.0               | Multidão densa (praça lotada) |
| Muito Alta   | 5.0               | Extremamente denso (show, ato massivo) |

### 3. Método Combinado (Híbrido)

Quando ambos os dados estão disponíveis (check-ins e área), o sistema faz uma média ponderada:

**Se check-ins ≥ 50:**
$$E = 0.6 \times E_{checkin} + 0.4 \times E_{jacobs}$$
Confiança: 70%

**Se check-ins < 50:**
$$E = 0.3 \times E_{checkin} + 0.7 \times E_{jacobs}$$
Confiança: 50%

## Níveis de Confiança

| Confiança | Condição |
|-----------|----------|
| Alta (0.7+) | ≥50 check-ins + cálculo de densidade |
| Média (0.4-0.6) | ≥20 check-ins OU densidade sem check-ins |
| Baixa (<0.4) | <20 check-ins, sem área definida |

## Referências

- Jacobs, H. (1967). "To Count a Crowd." *Columbia Journalism Review*, Spring 1967.
- Watson, R., & Yip, P. (2011). "How Many Were There When It Mattered?" *Significance*, 8(3).
- Prestige, G. (2019). "Crowd Counting Methods: A Survey." *arXiv preprint*.

## Exemplo Prático

Um protesto em uma praça de 10.000 m² com 150 check-ins ativos:

- **Método Check-in:** 150 × 8 = **1.200 pessoas**
- **Método Jacobs (densidade média):** 10.000 × 1.5 = **15.000 pessoas**
- **Método Combinado:** 0.6 × 1.200 + 0.4 × 15.000 = **6.720 pessoas** (confiança 70%)

A grande discrepância sugere que o nível de adoção do app é baixo (poucos check-ins proporcional ao tamanho). Ajustar o multiplicador ou usar estimativa de densidade mais conservadora pode ser mais preciso.
