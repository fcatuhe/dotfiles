#include "line.h"

#include <limits.h>
#include <wchar.h>

struct place {
  int row, col;
};

static int prompt_width, screen_width;
static struct place cursor;

/* -1 when the text is not decodable. */
int columns_within(const char *s, int n, int limit, int *bytes)
{
  mbstate_t state;
  int width = 0, used = 0;

  memset(&state, 0, sizeof state);
  while (used < n) {
    wchar_t wc;
    size_t len = mbrtowc(&wc, s + used, n - used, &state);
    int w;

    if (len == 0 || len == (size_t)-1 || len == (size_t)-2)
      return -1;
    w = wcwidth(wc);
    if (w < 0)
      return -1;
    if (width + w > limit)
      break;
    width += w;
    used += len;
  }
  if (bytes)
    *bytes = used;
  return width;
}

static int prompt_columns(void)
{
  const char *p = rl_display_prompt;
  const char *line;
  char visible[512];
  int n = 0, hidden = 0;

  if (!p)
    return 0;
  line = strrchr(p, '\n');
  p = line ? line + 1 : p;

  for (; *p && n < (int)sizeof visible - 1; p++) {
    if (*p == RL_PROMPT_START_IGNORE)
      hidden = 1;
    else if (*p == RL_PROMPT_END_IGNORE)
      hidden = 0;
    else if (!hidden)
      visible[n++] = *p;
  }
  visible[n] = '\0';
  return columns_within(visible, n, INT_MAX, NULL);
}

/* Rows count from the prompt's last line, a wide character wraps whole as readline draws it. */
static int place_of(int offset, struct place *place)
{
  mbstate_t state;
  int used = 0;

  place->row = prompt_width / screen_width;
  place->col = prompt_width % screen_width;
  memset(&state, 0, sizeof state);
  while (used < offset) {
    wchar_t wc;
    size_t len = mbrtowc(&wc, rl_line_buffer + used, offset - used, &state);
    int w;

    if (len == 0 || len == (size_t)-1 || len == (size_t)-2)
      return -1;
    w = wcwidth(wc);
    if (w < 0)
      return -1;
    if (place->col + w > screen_width) {
      place->row++;
      place->col = 0;
    }
    place->col += w;
    if (place->col == screen_width) {
      place->row++;
      place->col = 0;
    }
    used += len;
  }
  return 0;
}

static int drawn_as_typed(void)
{
  const char *scrolling = rl_variable_value("horizontal-scroll-mode");
  const char *up = rl_get_termcap("up");
  int i;

  if ((scrolling && strcmp(scrolling, "on") == 0) || !up || !*up)
    return 0;
  for (i = 0; i < rl_end; i++)
    if ((unsigned char)rl_line_buffer[i] < ' ' || rl_line_buffer[i] == 0x7f)
      return 0;
  return 1;
}

/* -1 when readline draws the line in a way this cannot follow. */
int screen_measure(void)
{
  int rows;

  if (!rl_line_buffer || !drawn_as_typed())
    return -1;
  rl_get_screen_size(&rows, &screen_width);
  prompt_width = prompt_columns();
  if (screen_width <= 0 || prompt_width < 0)
    return -1;
  return place_of(rl_point, &cursor);
}

void screen_move_to(int offset)
{
  struct place to;

  if (place_of(offset, &to) < 0)
    return;
  if (to.row < cursor.row)
    fprintf(rl_outstream, "\033[%dA", cursor.row - to.row);
  else if (to.row > cursor.row)
    fprintf(rl_outstream, "\033[%dB", to.row - cursor.row);
  fprintf(rl_outstream, "\033[%dG", to.col + 1);
}

/* One column short of the edge, so nothing wraps onto a row readline does not know about. */
int screen_room_after(int offset)
{
  struct place at;

  if (place_of(offset, &at) < 0)
    return 0;
  return screen_width - 1 - at.col;
}
