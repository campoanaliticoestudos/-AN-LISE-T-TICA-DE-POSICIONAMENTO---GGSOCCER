# ANÁLISE TÁTICA DE POSICIONAMENTO - GGSOCCER
# ==============================================================================
# Caminho do arquivo (ajuste conforme necessário)
arquivo <- "C:/Users/aldre/Downloads/Bahia_vs_Corinthians_base2024.csv"
partida <- read_csv(arquivo)

library(ggplot2)
library(ggsoccer)
library(patchwork)
library(showtext)
library(dplyr)
library(tidyr)
showtext_opts(dpi = 130) # Mantém proporção perfeita no ggsave e na tela


# 1. Configuração de Estética e Fontes
font_add_google("Roboto Slab", "roboto_slab")
showtext_auto()

# Definições auxiliares
ST <- list(grid_line = "#AAAAAA", dark = "#333333", f_base = "roboto_slab")

# 2. Mapeamento e Funções
mapeamento_tatico <- data.frame(
  zona = c("Atk_L", "Atk_LC", "Atk_C", "Atk_RC", "Atk_R",
           "Mid_L", "Mid_LC", "Mid_C", "Mid_RC", "Mid_R",
           "Def_L", "Def_LC", "Def_C", "Def_RC", "Def_R"),
  sigla = c("LW", "SS", "CF", "SS", "RW", "LM", "AM", "DM", "AM", "RM", "LB", "CB", "CB", "CB", "RB")
)

calc_zona_universal <- function(x, y) {
  setor_x <- case_when(x <= 33.3 ~ "Def", x <= 66.6 ~ "Mid", TRUE ~ "Atk")
  setor_y <- case_when(y <= 20 ~ "L", y <= 40 ~ "LC", y <= 60 ~ "C", y <= 80 ~ "RC", TRUE ~ "R")
  return(paste0(setor_x, "_", setor_y))
}

adicionar_grid_uefa <- function(p) {
  p + annotate("segment", x = c(16.66, 33.33, 50, 66.66, 83.33), xend = c(16.66, 33.33, 50, 66.66, 83.33),
               y = 0, yend = 100, colour = ST$grid_line, linewidth = 0.5, linetype = "dashed", alpha = 0.5) +
    annotate("segment", x = 0, xend = 100, y = c(33.33, 66.66), yend = c(33.33, 66.66),
             colour = ST$grid_line, linewidth = 0.5, linetype = "dashed", alpha = 0.5) +
    annotate("text", x = rep(c(8.33, 25, 41.66, 58.33, 75, 91.66), each = 3),
             y = rep(c(83.33, 50, 16.66), 6), label = 1:18,
             colour = ST$dark, size = 3, fontface = "bold", alpha = 0.2, family = ST$f_base)
}

table(partida$jogador)
# 3. Processamento
NOME_ALVO <- "Rodrigo Garro" 
df_jogador <- partida %>% 
  filter(jogador == NOME_ALVO) %>% 
  filter(!(type %in% c("SubstitutionOff", "SubstitutionOn"))) %>% 
  mutate(zona = calc_zona_universal(x, y))
stats_jogador <- df_jogador %>%
  group_by(zona) %>% summarise(n = n(), .groups = 'drop') %>%
  mutate(pct = (n / sum(n)) * 100) %>% filter(pct >= 10) %>% 
  left_join(mapeamento_tatico, by = "zona") %>% mutate(pct_text = paste0(round(pct, 1), "%"))

grid_coords <- expand.grid(setor_x = c("Def", "Mid", "Atk"), setor_y = c("L", "LC", "C", "RC", "R")) %>%
  mutate(zona = paste0(setor_x, "_", setor_y),
         zx = case_when(setor_x == "Def" ~ 16, setor_x == "Mid" ~ 50, TRUE ~ 84),
         zy = case_when(setor_y == "L" ~ 10, setor_y == "LC" ~ 30, setor_y == "C" ~ 50, setor_y == "RC" ~ 70, TRUE ~ 90))

data_plot <- grid_coords %>% inner_join(stats_jogador, by = "zona")
primary_pos <- data_plot %>% arrange(desc(pct)) %>% slice(1) %>% pull(sigla)
total_events <- nrow(df_jogador)

# 4. Construção dos Gráficos
# P1: Sigla DENTRO do ponto, Porcentagem ABAIXO
p1 <- adicionar_grid_uefa(ggplot(data_plot) + annotate_pitch(colour = "#D1D1D1", fill = "#ffffff", limits = FALSE)) +
  geom_point(aes(x = zx, y = zy, size = pct), shape = 21, fill = "#E57373", color = "#404040", stroke = 1, alpha = 1.2) +
  geom_text(aes(x = zx, y = zy, label = sigla), family = "roboto_slab", fontface = "bold", size = 4, color = "white") +
  geom_text(aes(x = zx-8, y = zy, label = pct_text), family = "roboto_slab", size = 3.5, color = "#404040") +
  scale_y_reverse() + scale_size_continuous(range = c(20, 26), guide = "none") +
  coord_flip() + theme_pitch() + theme(aspect.ratio = 1.4)

# P_HEAT: Com grade UEFA
# P_HEAT: Estilo mais encorpado e vivo (sem aspecto apagado)
p_heat <- adicionar_grid_uefa(
  ggplot(df_jogador) +
    annotate_pitch(dimensions = pitch_opta, fill = "#ffffff", colour = "#D1D1D1") +
    stat_density_2d(
      aes(x = x, y = y, fill = after_stat(level)), 
      geom = "polygon", 
      alpha = 0.75,      # Aumentado de 0.5 para 0.75 para dar mais solidez
      n = 200, 
      h = c(16, 16)      # Um pouco mais fechado (16) para manter o detalhe sem falhar
    ) +
    scale_fill_gradient(
      low = "#FFCDD2",   # Vermelho claro bem definido (substitui o branco apagado)
      high = "#C62828"   # Vermelho escuro e profundo (traz força visual)
    ) + 
    coord_flip() + 
    scale_y_reverse() +
    labs(subtitle = "Action Density") +
    theme_pitch() +
    theme(
      legend.position = "none",
      plot.background = element_rect(fill = "#ffffff", color = NA),
      text = element_text(family = ST$f_base),
      plot.subtitle = element_text(size = 11, hjust = 0.5, face = "italic"),
      aspect.ratio = 1.4
    )
)
# P_INFO e Montagem
p_info <- ggplot() +
  annotate("text", x = 0, y = 10, label = "Total Events", family = "roboto_slab", fontface = "bold", size = 6, hjust = 0) +
  annotate("text", x = 0, y = 8.5, label = as.character(total_events), family = "roboto_slab", size = 11, color = "#333333", hjust = 0) +
  annotate("text", x = 0, y = 6, label = "Primary Position", family = "roboto_slab", fontface = "bold", size = 6, hjust = 0) +
  annotate("text", x = 0, y = 4.5, label = primary_pos, family = "roboto_slab", size = 9, color = "#E57373", hjust = 0) +
  xlim(0, 10) + ylim(0, 12) + theme_void()

layout <- c(area(t = 1, l = 1, b = 10, r = 4), area(t = 1, l = 5, b = 4, r = 6), area(t = 5, l = 5, b = 10, r = 6))

final_plot <- p1 + p_info + p_heat + plot_layout(design = layout) +
  plot_annotation(title = NOME_ALVO, subtitle = "Tactical positioning analysis | Significant actions (>10%)",
                  theme = theme(plot.title = element_text(family = "roboto_slab", size = 32, face = "bold"),
                                plot.subtitle = element_text(family = "roboto_slab", size = 14, color = "#505050")))

print(final_plot)
      