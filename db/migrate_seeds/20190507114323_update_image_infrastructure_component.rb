class UpdateImageInfrastructureComponent < ActiveRecord::Migration[5.2]
  def up
    infrastructure_components = InfrastructureComponent.all
    infrastructure_components.each do |ic|
      ic.update(image: "18.04")
    end
  end

  def down
    infrastructure_components = InfrastructureComponent.all
    infrastructure_components.each do |ct|
      ic.update(image: nil)
    end
  end
end
