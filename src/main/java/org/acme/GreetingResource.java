package org.acme;

import java.sql.Connection;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

import javax.sql.DataSource;

import jakarta.inject.Inject;
import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;

@Path("/hello")
public class GreetingResource {

    @Inject
    DataSource dataSource;

    @GET
    public String hello() throws SQLException {
        try (Connection connection = dataSource.getConnection();
                Statement statement = connection.createStatement();
                ResultSet result = statement.executeQuery("SELECT message FROM greeting ORDER BY id DESC LIMIT 1")) {
            return result.next() ? result.getString(1) : "no greeting";
        }
    }
}
