#!/usr/bin/env python3.10

from unicodedata import category
from todo_queue import Task, TodoQueue, TIME_FORMAT, TASK_CATEGORY_ALIASES
import datetime
from NicePrinter import title, bold, box, table
import random
import datetime
import csv
import os
import sys

"""
Future instruction:
    - change priority, cp
    - rename: rn
    - suggest random task for boredom
    - search by category: sbc
    - archive completed tasks:
    - undo (advanced)
    - retrieve from completed tasks
        - add ids to completed tasks
"""

class Main:
    def __init__(self, mobile = "", task_filename = "tasks.csv", log_filename = "completed_tasks.csv"):
        dirname = os.path.dirname(__file__)
        self.task_filename = os.path.join(dirname, task_filename)
        self.log_filename = os.path.join(dirname,log_filename)
        self.q = TodoQueue()
        if mobile == "1":
            self.q.mobile = True
        
        self.instructions = {
            "add": (self.add, "a", "Add one task to the queue.",  ["[Optional[str]]: Name of task"]),
            "complete": (self.complete, "c", "Complete a task at the front of the queue.", ["[Optional[int]]: Local id of task if not front of queue"]),
            "delete": (self.delete, "del", "Delete (not complete) a task given a local id.", ["[int]: Local id of task to delete"]),
            "drop": (self.drop, "d", "Drop front task to bottom of its priority in queue.", ["[Optional[int]]: Local id of task if not front of queue"]),
            "print": (self.print_tasks, "p", "Print queue.", ["[Optional[int]]: Limit output tasks"]),
            "switch_mobile": (self.switch_mobile, "sm", "Switch to and from mobile mode  which limits printing tasks to id, name and priority for mobile interface"),
            "random": (self.random_tasks, "r", "Selects random tasks from every priority."),
            "category_filter": (self.category_filter, "filter", "Filter by category.", ["[str]: Category to filter by"]),
            "search_name": (self.search_name, "search", "Search by name substring", ["[str]: Substring to filter by"]),
            "priority_filter": (self.priority_filter, "pfilter", "Filter by priority.", ["[int]: Priority to filter by"]),
            "done": (self.done, "done", "Save and show completed tasks."),
            "info": (lambda x: self.info(), "i", "Print available actions."),
            "archive_completed": (self.archive, "ac", "Archive completed tasks."),
            "exit": (self.exit, "e", "Save queue and exit."),
            "clear": (lambda x: os.system('clear'), "clear", 'Clear terminal.'),
        }   
        
        self.start()
        self.main_loop()
    
    def main_loop(self):

        os.system('clear')
        print(title("Let's get shit done!"))
        print(self.q)
        self.info()

        aliases = {self.instructions[i][1]:i for i in self.instructions}

        def parse_instructions(inp):
            action = inp.split()[0]
            if action in aliases:
                action = aliases[action]
            args = inp.split()[1:]
            return action, args

        valid_inputs = list(self.instructions.keys()) + list(aliases.keys())
        while True:
            action, args = self.get_input(type = "non-empty text", 
                                out_text_override = "",
                                input_test_override = lambda x: x.split()[0] in valid_inputs,
                                input_conversion_override = lambda x: parse_instructions(x))
            self.instructions[action][0](args)
            print()

    def switch_mobile(self, args):
        self.q.mobile = not self.q.mobile
        print(f"Mobile mode switched to {self.q.mobile}.")

    def random_tasks(self, args):
        tasks = [random.choice(self.q.filter(lambda task: task.priority == i)) for i in range(5)]
        print(self.q.output_table(tasks))

    def print_tasks(self, args):
        if args:
            if len(args) == 1 and args[0].isnumeric():
                print(self.q.get_top_k(int(args[0])))
            else: 
                print("Print takes one numeric argument and it must match the local id of an existing task.")
                return
        else:
            print(self.q)

    def priority_filter(self, args):
        if len(args) == 1 and args[0].isnumeric(0):
            tasks = self.q.filter(lambda task: task.priority == int(args[0]))
            print(self.q.output_table(tasks))
        else:
            print("Priority filter takes one numeric argument.")   

    def search_name(self, args):
        if len(args) == 1:
            tasks = self.q.filter(lambda task: args[0] in task.name)
            print(self.q.output_table(tasks))
        else:
            print("Search name takes one argument.")

    def category_filter(self, args):
        if len(args) == 1:
            tasks = self.q.filter(lambda task: task.category == args[0])
            print(self.q.output_table(tasks))
        else:
            print("Category filter takes one argument.")


    def archive(self, args):
        self.log_file.close()
        
        current_dir = os.path.dirname(__file__)
        archive_dir = os.path.join(current_dir, "archive")
        if not os.path.exists(archive_dir):
            os.mkdir(archive_dir)
            print("Created archive directory,")
        os.rename(self.log_filename, os.path.join(archive_dir, datetime.datetime.now().strftime('%Y%m%dT%H:%M:%S')) + "_"+ os.path.basename(self.log_filename))
        
        self.log_file = open(self.log_filename, 'w')
        self.logger = csv.writer(self.log_file)
        self.logger.writerow(Task.get_attribute_names() + ["time_completed"])
        print("Old completed tasks archived and new task log set up.")

    def done(self, args):
        self.log_file.close()
        with open(self.log_filename, "r") as readfile:
            print(table(list(csv.reader(readfile)), centered=True))
        self.log_file = open(self.log_filename, "a")
        self.logger = csv.writer(self.log_file)


    def exit(self, args):
        self.save()
        print("Successfully exit, have a swell day and go do drugs.")
        exit()
    
    def drop(self, args):
        if args:
            if len(args) == 1 and args[0].isnumeric() and int(args[0]) in self.q.ids:
                drop_task = self.q.pull_given_id(int(args[0]))
            else:
                print("Drop takes one numeric argument and it must match the local id of an existing task.")
                return
        else:
            if self.q.empty():
                print("There are no tasks to drop.")
                return
            else:
                drop_task = self.q.pull_first()
        self.q.put(drop_task)
        print(self.q.get_top_k())
        print(f"Successfully dropped {drop_task.name} (id {drop_task.local_id}) at {datetime.datetime.now().strftime(TIME_FORMAT)}.")

    def complete(self, args):
        if args:
            if len(args) == 1 and args[0].isnumeric() and int(args[0]) in self.q.ids:
                completed_task = self.q.pull_given_id(int(args[0]))
            else: 
                print("Complete takes one numeric argument and it must match the local id of an existing task.")
                return
        else:
            if self.q.empty():
                print("There are no tasks to complete.")
                return
            else:
                completed_task = self.q.pull_first()
        self.log(completed_task)
        print(self.q.get_top_k())
        print(f"Successfully completed {completed_task.name} (id {completed_task.local_id}) at {datetime.datetime.now().strftime(TIME_FORMAT)}.")
            
    def delete(self, args):
        if len(args) == 1 and args[0].isnumeric() and int(args[0]) in self.q.ids:
            deleted_task = self.q.pull_given_id(int(args[0]))
        else:
            print("Delete takes one numeric agument and it must match the local id of an existing task.")
            return
        print(f"Successfully deleted {deleted_task.name} (id {deleted_task.local_id}) at {datetime.datetime.now().strftime(TIME_FORMAT)}.")

            
    
    def add(self, args):
        if args:
            name = " ".join(args)
        else:
            name = self.get_input(type = "non-empty text", out_text_override = "Task name\n")
        local_id = self.q.increment_counter()
        priority = self.get_input(type = "int", 
                                    out_text_override = "Priority [0:now | 1:day | 2:week | 3:month | 4:non-urgent]\n", 
                                    input_test_override = lambda x: len(x) == 1 and x in '01234',
                                    default_input="2")
        category = self.get_input(type = "non-empty text", 
                                    out_text_override = f"Category {TASK_CATEGORY_ALIASES} or manual input\n", 
                                    input_conversion_override = lambda x: TASK_CATEGORY_ALIASES[x] if x in TASK_CATEGORY_ALIASES else x,
                                    default_input="misc")
        time_created = datetime.datetime.now()
        description = self.get_input(type = "text", 
                                    out_text_override = f"Description\n",)
        self.q.put(Task(local_id, name, priority, category, time_created, description))
        self.category_filter([category])

    def info(self):
        print(box("Possible actions"))
        for i in self.instructions:
            details = self.instructions[i]
            print(bold(f"{i} ({details[1]})") + f" - {details[2]}")
            if len(details) > 3:
                [print("   " + arg) for arg in details[3]]        


    def start(self):
        print(title("Welcome to your To-Do Queue", 90, '='))
        print(f"To get started, would you like to use '{self.task_filename}' to retrieve and store existing tasks?")
        if self.get_input(default_input="y"):
            if os.path.exists(self.task_filename):
                self.load()
                print("Successfully loaded from file.")
            else:
                print(f"File doesn't exist. New file '{self.task_filename}' will be created after exiting.")
        else:
            print("Set new filename.")
            self.task_filename = self.get_input(type="non-empty text")
            # Check if file exists and set overload
        print("Task file setup complete.\n")

        print(f"Would you like to use '{self.log_filename}' to store completed tasks?")
        if not self.get_input(default_input="y"):
            self.log_filename = self.get_input(type="non-empty text")
        
        log_file_existed = os.path.exists(self.log_filename)
        self.log_file = open(self.log_filename, 'a')
        self.logger = csv.writer(self.log_file)
        if not log_file_existed:
            self.logger.writerow(Task.get_attribute_names() + ["time_completed"])
            print("New logging file created. ", end="")
        print("Task log setup complete.\n")

    def save(self):
        with open(self.task_filename, 'w') as outfile:
            task_writer = csv.writer(outfile)
            task_writer.writerow(Task.get_attribute_names())
            for task in self.q:
                task_writer.writerow(task.get_properties().values())
        self.log_file.close()
        
    def log(self, task):
        self.logger.writerow(list(task.get_properties().values()) + [datetime.datetime.now().strftime(TIME_FORMAT)])

    def load(self):
        # Check valid file
        with open(self.task_filename, 'r') as infile:
            task_reader = csv.reader(infile)
            next(task_reader)
            for row in task_reader:
                new_task = Task(
                    self.q.increment_counter(), 
                    row[1], int(row[3]), row[4], 
                    datetime.datetime.strptime(row[2], TIME_FORMAT),
                    row[5],
                    datetime.datetime.strptime(row[6], TIME_FORMAT) if row[6] else None,
                )
                self.q.put(new_task)

    def get_input(self, type = "yes-no", default_input = None, invalid_input_text = "Invalid input, please try again.",
                    out_text_override = None, input_test_override = None, input_conversion_override = None):
        # overrides for input test and input conversion

        input_types =\
        {
            "yes-no": ("[y/n] ", lambda x: x in ["y", "n"], lambda x: x == "y"),
            "int": ("[int] ", lambda x: x.isnumeric(), lambda x: int(x)),
            "non-empty text": ("[str] ", lambda x: bool(x), lambda x: x),
            "text": ("[str] ", lambda x: True, lambda x: x),
        }

        out_text, input_test, input_conversion = input_types[type]
        out_text = out_text_override if out_text_override != None else out_text
        input_test = input_test_override if input_test_override else input_test
        input_conversion = input_conversion_override if input_conversion_override else input_conversion

        if default_input:
            out_text += f"(default {default_input})"
        out_text += ": "

        while not input_test(inp := input(out_text).lower()):
            if default_input and not inp:
                return input_conversion(default_input)
            print(invalid_input_text)

        return input_conversion(inp)

if __name__ == "__main__":
    os.system('clear')
    Main(*sys.argv[1:])
