import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:research_package/research_package.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../web_services_api/api.dart';

class SurveyTaskRoute extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return RPUITask(
      task: _who5Task,
      onSubmit: (result) async {

        List<String> questions = [];
        List<int> choices = [];

        for (RPStep question in _who5Task.steps) {
          questions.add(question.title);
        }

        final _dataPoint = {
          "carp_header": {
            "study_id": "aFeH8",
            "device_role_name":
            "masterphone with USER_CODE = A3FNzaFeH8. Local Time = ${DateTime.now().toString()}",
            "user_id": "A3FN",
            "start_time": DateTime.now().toUtc().toIso8601String(),
            "data_format": {"namespace": "dk.cachet.carp", "name": "adhoc"}
          },
          "carp_body": {
            "id": "6f77caed-5067-4877-a26d-f94386c0984b",
            "survey_data": result.toJson()
          }
        };

        print(json.encode(_dataPoint));

        Api api = Api();

        print("HTTP POST TOKEN");
        Map<String, dynamic> jsonPostToken = await api.postToken(
            numAttemps: 5, timeoutDuration: const Duration(seconds: 5));

        print("HTTP GET TOKEN");
        Map<String, dynamic> jsonGetToken = await api.getToken(
            jsonPostToken["access_token"],
            numAttemps: 5,
            timeoutDuration: const Duration(seconds: 5));

        print("HTTP POST DATAPOINT");
        Map<String, dynamic> jsonPostDatapoint = await api.postDataPoint(
            jsonPostToken["access_token"], json.encode(_dataPoint),
            numAttemps: 5, timeoutDuration: const Duration(seconds: 5));
        print(jsonPostDatapoint);


        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('surveyReady', false);

        SystemNavigator.pop();
      },
      onCancel: (RPTaskResult? result) {
        // your code
      },
    );
  }
}

RPOrderedTask _who5Task = RPOrderedTask(
  identifier: "who5_task",
  steps: [
    _who5Question1,
    _who5Question2,
    _who5Question3,
    _who5Question4,
    _who5Question5,
    _completionStep,
  ],
);

List<RPChoice> _who5Choices = [
  RPChoice(text: "All of the time", value: 5),
  RPChoice(text: "Most of the time", value: 4),
  RPChoice(text: "More than half of the time", value: 3),
  RPChoice(text: "Less than half of the time", value: 2),
  RPChoice(text: "Some of the time", value: 1),
  RPChoice(text: "At no time", value: 0),
];

RPChoiceAnswerFormat _choiceAnswerFormat = RPChoiceAnswerFormat(
    answerStyle: RPChoiceAnswerStyle.SingleChoice, choices: _who5Choices);

RPQuestionStep _who5Question1 = RPQuestionStep(
  identifier: "who5_question_1",
  title: "I have felt cheerful and in good spirits",
  answerFormat: _choiceAnswerFormat,
);

RPQuestionStep _who5Question2 = RPQuestionStep(
  identifier: "who5_question_2",
  title: "I have felt calm and relaxed",
  answerFormat: _choiceAnswerFormat,
);

RPQuestionStep _who5Question3 = RPQuestionStep(
  identifier: "who5_question_3",
  title: "I have felt active and vigorous",
  answerFormat: _choiceAnswerFormat,
);

RPQuestionStep _who5Question4 = RPQuestionStep(
  identifier: "who5_question_4",
  title: "I woke up feeling fresh and rested",
  answerFormat: _choiceAnswerFormat,
);

RPQuestionStep _who5Question5 = RPQuestionStep(
  identifier: "who5_question_5",
  title: "My daily life has been filled with things that interest me",
  answerFormat: _choiceAnswerFormat,
);

RPCompletionStep _completionStep = RPCompletionStep(
  identifier: "completion_step",
  title: "Finished",
  text: "Thank you for filling out the survey!",
);