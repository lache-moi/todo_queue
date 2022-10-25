#!/usr/bin/env python3.10

from todo_queue import Task, TodoQueue, TIME_FORMAT, TASK_CATEGORY_ALIASES, DAYS_TO_ESCALATE
import datetime
from NicePrinter import title, bold, box, table
import random
import datetime
import csv
import os
import sys

"""
Future instruction:
    - undo (advanced)
    - retrieve from completed tasks
        - add ids to completed tasks
"""

class Main:
    def __init__(self, mobile = False, auto_start = True, task_filename = "tasks.csv", log_filename = "completed_tasks.csv"):
        dirname = os.path.dirname(__file__)
        self.task_filename = os.path.join(dirname, task_filename)
        self.log_filename = os.path.join(dirname, log_filename)
        self.q = TodoQueue()
        self.q.mobile = mobile
        self.auto_start = auto_start
        
        self.instructions = {
            # Basic
            "add": (self.add, "a", "Add one task to the queue.",  ["[Optional[str]]: Name of task"]),
            "complete": (self.complete, "c", "Complete a task at the front of the queue.", ["[Optional[int]]: Local id of task if not front of queue"]),
            "delete": (self.delete, "del", "Delete (not complete) a task given a local id.", ["[int]: Local id of task to delete"]),

            # Priority change
            "drop": (self.drop, "d", "Drop front task to bottom of its priority in queue.", ["[Optional[int]]: Local id of task if not front of queue"]),
            "escalate": (self.escalate, "esc", "Escalates given task to next priority", ["[int]: Local id of task to escalate"]), 
            "deesclate": (self.deescalate, "desc", "De-escalates given task to previous priority", ["[int]: Local id of task to de-escalate"]),

            # Attribute change
            "change_name": (self.change_name, "cn", "Change name of given task.", ["[int]: Local id of task of which to change name", "[str]: Name to which to change"]),
            "change_category": (self.change_category, "cc", "Change category of given task.", ["[int]: Local id of task of which to change category", "[str]: Category to which to change"]),
            "change_description": (self.change_description, "cd", "Change description of given task.", ["[int]: Local id of task of which to change description", "[str]: Description to which to change"]),
            "change_escalate_time": (self.change_escalate_time, "cet", "Change escalate time of given task.", ["[int]: Local id of task of which to change esclate time", "[int]: Days from today to set escalate time"]),

            # Display
            "print": (self.print_tasks, "p", "Print queue.", ["[Optional[int]]: Limit output tasks"]),
            "random": (self.random_tasks, "r", "Selects random tasks from every priority."),
            "search_name": (self.search_name, "search", "Search by name substring", ["[str]: Substring to filter by"]),
            "category_filter": (self.category_filter, "filter", "Filter by category.", ["[str]: Category to filter by"]),
            "priority_filter": (self.priority_filter, "pfilter", "Filter by priority.", ["[int]: Priority to filter by"]),
            "switch_mobile": (self.switch_mobile, "sm", "Switch to and from mobile mode  which limits printing tasks to id, name and priority for mobile interface"),

            # Completed tasks
            "done": (self.done, "done", "Save and show completed tasks."),
            "archive_completed": (self.archive, "ac", "Archive completed tasks."),

            # Miscellaneous
            "info": (lambda x: self.info(), "i", "Print available actions."),
            "clear": (lambda x: os.system('clear'), "clear", 'Clear terminal.'),
            "exit": (self.exit, "e", "Save queue and exit."),
        }   
        
        self.start()
        self.main_loop()
    
    def main_loop(self):

        os.system('clear')
        print(title("Let's get shit done!"))
        print(self.q)
        self.simple_info()
        print()

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
                                input_test_override = lambda x:x and x.split()[0] in valid_inputs,
                                input_conversion_override = lambda x: parse_instructions(x))
            self.instructions[action][0](args)
            self.save()
            print()

    def change_name(self, args):
        if not (len(args) >= 2 and args[0].isnumeric() and int(args[0]) in self.q.ids):
            print("Change name takes multiple arguments and the first numeric argument must match the local id of an existing task.")
            return
        change_task = self.q.get_given_id(int(args[0]))
        previous_name = change_task.name
        change_task.set_name(" ".join(args[1:]))
        print(f"Name of '{previous_name}' ({change_task.local_id}) set to '{change_task.name}'")

    def change_category(self, args):
        if not (len(args) == 2 and args[0].isnumeric() and int(args[0]) in self.q.ids):
            print("Change category takes two arguments and the first numeric argument must match the local id of an existing task.")
            return
        change_task = self.q.get_given_id(int(args[0]))
        previous_category = change_task.category
        change_task.set_category(args[1])
        print(f"Category of '{change_task.name}' ({change_task.local_id}) set from {previous_category} to {change_task.category}")

    def change_description(self, args):
        if not (len(args) >= 2 and args[0].isnumeric() and int(args[0]) in self.q.ids):
            print("Change description takes multiple arguments and the first numeric argument must match the local id of an existing task.")
            return

        change_task = self.q.get_given_id(int(args[0]))
        change_task.set_description(" ".join(args[1:]))
        print(f"Description of '{change_task.name}' ({change_task.local_id}) set to '{change_task.description}'")

    def change_escalate_time(self, args):
        if not (len(args) == 2 and args[0].isnumeric() and int(args[0]) in self.q.ids and args[1].isnumeric()):
            print("Change escalate takes two numerical arguments and the first numeric argument must match the local id of an existing task.")
            return

        change_task = self.q.get_given_id(int(args[0]))
        days = int(args[1])
        if change_task.priority == 0:
            print("Task priority is already urgent, escalate time cannot be changed.")
            return

        if not(0 < days <= DAYS_TO_ESCALATE[change_task.priority]):
            print(f"Task priority is {change_task.priority}, second argument must therefore be a positive integer leq to {DAYS_TO_ESCALATE[change_task.priority]}.")
            return
        
        now = datetime.datetime.now()
        change_task.set_escalate_time(datetime.datetime(now.year, now.month, now.day) + datetime.timedelta(days = days))
        print(f"Escalate time of '{change_task.name}' ({change_task.local_id}) set to '{change_task.calc_days_til_escalate()}'")
    
    def escalate(self, args):

        if not (len(args) == 1 and args[0].isnumeric() and int(args[0]) in self.q.ids):
            print("Escalate takes one numeric argument and it must match the local id of an existing task.")
            return

        escalate_task = self.q.pull_given_id(int(args[0]))
        print(f"'{escalate_task.name}' (id {escalate_task.local_id}) is P{escalate_task.priority} prior to escalation.")   
        escalate_task.escalate(force = True)
        self.q.put(escalate_task)
        tasks  = self.q.filter(lambda task: task.category == escalate_task.category)
        print(self.q.output_table(tasks))
        print(f"Task successfully escalated. It is now P{escalate_task.priority} and has escalate time of {escalate_task.calc_days_til_escalate()}")   


    def deescalate(self, args):
        if not (len(args) == 1 and args[0].isnumeric() and int(args[0]) in self.q.ids):
            print("Deescalate takes one numeric argument and it must match the local id of an existing task.")
            return

        deescalate_task = self.q.pull_given_id(int(args[0]))
        print(f"'{deescalate_task.name}' (id {deescalate_task.local_id}) is P{deescalate_task.priority} prior to de-escalation.")     
        deescalate_task.deescalate()
        self.q.put(deescalate_task)
        tasks  = self.q.filter(lambda task: task.category == deescalate_task.category)
        print(self.q.output_table(tasks))
        print(f"Task successfully deescalated. It is now P{deescalate_task.priority} and has escalate time of {deescalate_task.calc_days_til_escalate()}")   

    def switch_mobile(self, args):
        self.q.mobile = not self.q.mobile
        print(f"Mobile mode switched to {self.q.mobile}.")

    def random_tasks(self, args):
        tasks = [random.choice(self.q.filter(lambda task: task.priority == i)) for i in range(5) if self.q.filter(lambda task: task.priority == i)]
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
        if len(args) == 1 and args[0].isnumeric():
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
        self.log_file.close()
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
    
    def simple_info(self):
        simple_actions  = ["add", "complete", "delete", "print", "info", "exit"]
        print(box("Possible actions"))
        simple_instructions = {key:value for (key,value) in self.instructions.items() if key in simple_actions}
        for i in simple_instructions:
            details = self.instructions[i]
            print(bold(f"{i} ({details[1]})") + f" - {details[2]}")
            if len(details) > 3:
                [print("   " + arg) for arg in details[3]]       

    def start(self):
        print(title("Welcome to your To-Do Queue", 90, '='))
        print(f"To get started, would you like to use '{self.task_filename}' to retrieve and store existing tasks?")

        if not self.auto_start:
            if not self.get_input(default_input="y"):
                print("Set new filename.")
                self.task_filename = self.get_input(type="non-empty text")

        if os.path.exists(self.task_filename):
            self.load()
            print("Successfully loaded from file.")
        else:
            print(f"File doesn't exist. New file '{self.task_filename}' will be created after exiting.")
        print("Task file setup complete.\n")

        print(f"Would you like to use '{self.log_filename}' to store completed tasks?")
        if not self.auto_start:
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
        self.log_file = open(self.log_filename, 'a')
        self.logger = csv.writer(self.log_file)
        
    def log(self, task):
        self.logger.writerow(list(task.get_properties().values()) + [datetime.datetime.now().strftime(TIME_FORMAT)])

    def load(self):
        with open(self.task_filename, 'r') as infile:
            task_reader = csv.reader(infile)
            header = next(task_reader)
            
            name_i, time_created_i, priority_i, category_i, description_i, escalate_time_i =\
                header.index("name"), header.index("time_created"), header.index("priority"), header.index("category"), header.index("description"), header.index("escalate_time")

            for row in task_reader:
                new_task = Task(
                    local_id = self.q.increment_counter(),
                    name = row[name_i],
                    priority = int(row[priority_i]),
                    category = row[category_i],
                    time_created = datetime.datetime.strptime(row[time_created_i], TIME_FORMAT),
                    description = row[description_i],
                    escalate_time = datetime.datetime.strptime(row[escalate_time_i], TIME_FORMAT) if row[escalate_time_i] else None,
                )
                self.q.put(new_task)

    def get_input(self, type = "yes-no", default_input = None, invalid_input_text = "Invalid input, please try again.",
                    out_text_override = None, input_test_override = None, input_conversion_override = None):

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

    def check_sys_args(args):
        parsed_args = []

        if not (1 <= len(args) <= 5):
            return

        if len(args) >= 2:
            if args[1] not in ['0', '1']:
                return
            parsed_args.append(args[1] == '1')

        if len(args) >= 3:
            if args[2] not in ['0', '1']:
                return
            parsed_args.append(args[2] == '1')
            parsed_args.extend(args[3:])

        return parsed_args

    
    parsed_args = check_sys_args(sys.argv)
    print(parsed_args)

    if parsed_args != None:
        Main(*parsed_args)
    else:
        print("Invalid Arguments")
