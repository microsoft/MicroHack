import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

public class OracleConnectionTest1 {
    public static void main(String[] args) {
        String jdbcUrl = "jdbc:oracle:thin:@oracle-xe1:1521:XE";
        String username = "demo_schema";
        String password = "password";

        try {
            Connection connection = DriverManager.getConnection(jdbcUrl, username, password);
            System.out.println("Connected to Oracle database!");

            // Create a statement
            Statement statement = connection.createStatement();

            // Execute a query to get the database version
            String query = "SELECT * FROM v$version";
            ResultSet resultSet = statement.executeQuery(query);

            // Print the database version
            while (resultSet.next()) {
                System.out.println("Database Version: " + resultSet.getString(1));
            }

            // Close the connection
            connection.close();
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}