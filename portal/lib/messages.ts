// The portal's wording for the backend's message codes (backend/app/messages.py, PORTAL).
// backend/tests/test_curriculum.py checks that every portal code is here.
export const portalMessages: Record<string, string> = {
  teacher_key_required: "This portal isn't signed in to Magana. Ask the Magana team for access.",
  teacher_portal_off: "Saving quizzes isn't set up on this server yet.",
  quiz_not_found: "That quiz wasn't found. It may have been removed.",
  quiz_not_ready: "Fix the problems in “Before you assign” first.",
  quiz_no_questions: "Add at least one question.",
  quiz_empty_question: "Type the question.",
  quiz_too_few_options: "Give at least two options.",
  quiz_too_many_options: "Too many options for this class.",
  quiz_empty_option: "An option is empty.",
  quiz_no_right_answer: "Mark the right answer.",
  quiz_picture_needs_description: "Describe the picture in words. Magana reads the description.",
  quiz_question_long: "Long for a primary class: 15 words or fewer is easier to hear.",
  quiz_translation_unchecked: "The translation is not yet checked.",
  // The portal's own (no server reply).
  unreachable: "Can't reach the Magana server. Your quiz is still on this page: try again.",
  server_sleeping: "Magana’s server is sleeping. Please try again later. Your quiz is still on this page.",
};

export const messageFor = (code: string) => portalMessages[code] ?? "Something went wrong. Please try again.";
