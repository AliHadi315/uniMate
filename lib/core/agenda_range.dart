/// Date-range filters offered by the Agenda tab.
///
/// Lives in core (not in the screen) so other parts of the app — e.g. the
/// dashboard stat cards — can deep-link into a specific agenda view without
/// importing a screen.
enum AgendaRange { today, week, upcoming, overdue, all }
