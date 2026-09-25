#include "line.h"

#define GREY "\033[90m"

static int offered, on_screen;

static const char *history_completion(void)
{
  HIST_ENTRY **entries = history_list();
  int i;

  if (!entries || rl_end == 0)
    return NULL;
  for (i = history_length - 1; i >= 0; i--) {
    const char *entry = entries[i]->line;
    if (strncmp(entry, rl_line_buffer, rl_end) == 0 && entry[rl_end])
      return entry + rl_end;
  }
  return NULL;
}

/* zsh-autosuggestions clears on these, until the line is edited again. */
static int just_moved_through_history(void)
{
  return rl_last_func == rl_history_search_backward ||
         rl_last_func == rl_history_search_forward || rl_last_func == rl_get_previous_history ||
         rl_last_func == rl_get_next_history || rl_last_func == rl_beginning_of_history ||
         rl_last_func == rl_end_of_history;
}

static int printable_length(const char *s)
{
  int n = 0;

  while ((unsigned char)s[n] >= ' ' && s[n] != 0x7f)
    n++;
  return n;
}

void withdraw_suggestion(void)
{
  offered = 0;
}

void paint_suggestion(void)
{
  const char *rest;
  int room, bytes;

  if (RL_ISSTATE(RL_STATE_ISEARCH | RL_STATE_NSEARCH) || just_moved_through_history())
    return;
  rest = history_completion();
  room = screen_room_after(rl_end);
  if (!rest || room <= 0 || columns_within(rest, printable_length(rest), room, &bytes) <= 0)
    return;

  fprintf(rl_outstream, SAVE_CURSOR);
  screen_move_to(rl_end);
  fprintf(rl_outstream, ERASE_TO_END_OF_ROW GREY "%.*s" RESET RESTORE_CURSOR, bytes, rest);
  offered = on_screen = 1;
}

void erase_suggestion(void)
{
  if (!on_screen)
    return;
  on_screen = 0;
  if (screen_measure() < 0)
    return;
  fprintf(rl_outstream, SAVE_CURSOR);
  screen_move_to(rl_end);
  fprintf(rl_outstream, ERASE_TO_END_OF_ROW RESTORE_CURSOR);
  fflush(rl_outstream);
}

/* Readline echoes ^C at the cursor before it lets go, and the echo stays. */
void erase_suggestion_after_echo(void)
{
  if (!on_screen || rl_point != rl_end) {
    erase_suggestion();
    return;
  }
  on_screen = 0;
  fprintf(rl_outstream, ERASE_TO_END_OF_ROW);
  fflush(rl_outstream);
}

static const char *acceptable(void)
{
  return offered && rl_point == rl_end ? history_completion() : NULL;
}

int forward_char_or_accept(int count, int key)
{
  const char *rest = acceptable();

  if (!rest)
    return rl_forward_char(count, key);
  rl_insert_text(rest);
  return 0;
}

int end_of_line_or_accept(int count, int key)
{
  const char *rest = acceptable();

  if (!rest)
    return rl_end_of_line(count, key);
  rl_insert_text(rest);
  return 0;
}

static int is_word_character(char c)
{
  return (unsigned char)c >= 0x80 || (c >= '0' && c <= '9') || ((c | 32) >= 'a' && (c | 32) <= 'z');
}

/* Takes what forward-word would cross, as zsh-autosuggestions' partial accept does. */
int forward_word_or_accept_word(int count, int key)
{
  const char *rest = acceptable();
  char *word;
  int n = 0;

  if (!rest)
    return rl_forward_word(count, key);
  while (rest[n] && !is_word_character(rest[n]))
    n++;
  while (rest[n] && is_word_character(rest[n]))
    n++;
  word = strndup(rest, n);
  if (!word)
    return 1;
  rl_insert_text(word);
  free(word);
  return 0;
}
