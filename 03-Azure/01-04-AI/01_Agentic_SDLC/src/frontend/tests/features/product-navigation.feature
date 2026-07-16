Feature: Product catalog discovery
  As a supply chain planner
  I want to access the product catalog from the home page and search for products
  So that I can quickly evaluate items to fulfill upcoming orders

  Scenario: Navigate from the home page to the product catalog
    Given I am on the home page
    When I select the Products navigation link
    Then I land on the product catalog page
    And I see the catalog header "Products"

  Scenario: Search for a product by name
    Given I am viewing the product catalog
    And the catalog includes "SmartFeeder One"
    When I search for "SmartFeeder"
    Then the results list shows "SmartFeeder One"
    And the product description is visible in the results

  Scenario: Search for a product with no matches
    Given I am viewing the product catalog
    When I search for "Space Tuna"
    Then I see the empty state message "No products found"
    And I am prompted to adjust the search filters