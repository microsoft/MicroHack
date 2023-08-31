# Walkthrough Challenge 4

## Task 1

- Create a new Monitoring Workbook named `Monitor Microhack`

![Task1](./img/task_01_a.png)

## Task 2

- Add an Parameter names `Time Range` of type `Time Range Picker`

![Task1](./img/task_01_b.png)

![Task1](./img/task_01_c.png)

- Add a Query to the workbook

![Task1](./img/task_01_d.png)

In the **Columns Settings**, set:

Cpu

- Column renderer: Thresholds
- Custom number formatting: checked
- Units: Percentage
- Threshold settings (last two need to be in order):
- Icon: Success, Operator: Default
- Icon: Critical, Operator: >, Value: 80
- Icon: Warning, Operator: >, Value: 60

Trend

- Column renderer: Spark line
- Color palette: Green to Red
- Minimum value: 60
- Maximum value: 80

Click **Save and close** to commit the changes.

## Task 3

![Task1](./img/task_01_e.png)

- Pin the workbook to the dashboard. Choose **Pin All** to pin all the tiles to the dashboard.

![Task1](./img/task_01_g.png)

- Choose your Dashboard and verify that the workbook is pinned.

![Task1](./img/task_01_f.png)

- End result

![Task3](./img/task_3_dashboard.png)
