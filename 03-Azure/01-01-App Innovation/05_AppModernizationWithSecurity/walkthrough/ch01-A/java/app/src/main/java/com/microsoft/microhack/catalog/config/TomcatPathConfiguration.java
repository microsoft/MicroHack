package com.microsoft.microhack.catalog.config;

import org.springframework.boot.tomcat.servlet.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Lets the application reject encoded separators through its canonical image-key validator. */
@Configuration
public class TomcatPathConfiguration {

    /** Passes encoded separators through without decoding them into routable path segments. */
    @Bean
    WebServerFactoryCustomizer<TomcatServletWebServerFactory> imagePathCustomizer() {
        return factory -> factory.addConnectorCustomizers(connector -> {
            connector.setEncodedSolidusHandling("passthrough");
            connector.setEncodedReverseSolidusHandling("passthrough");
            connector.setAllowBackslash(true);
            connector.setProperty("relaxedPathChars", "\\");
        });
    }
}
